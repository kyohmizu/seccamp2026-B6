#!/usr/bin/env bash
# GCE VM 上に Verdaccio（公開npmの代役）を立てる。
# ・COS VM をコンテナ起動用 startup-script で作成
# ・ファイアウォールは Google の公開IPレンジのみ許可（＝インターネット全体には開けない粗い制限）
# ・認証情報は使用しない（npm は URL へ認証なしでアクセス。アクセス制限はこのファイアウォールで担う）
#
# 使い方: PROJECT=YOUR_PROJECT ZONE=asia-northeast1-b gce/provision.sh
# 事前に gcloud 認証済みであること。VM 作成は課金対象。
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="${PROJECT:?PROJECT を指定してください}"
ZONE="${ZONE:-asia-northeast1-b}"
NAME="${NAME:-verdaccio-demo}"
MACHINE="${MACHINE:-e2-small}"
TAG="verdaccio-demo"

echo "== VM 作成: $NAME ($PROJECT / $ZONE) =="
gcloud compute instances create "$NAME" \
  --project "$PROJECT" --zone "$ZONE" --machine-type "$MACHINE" \
  --image-family cos-stable --image-project cos-cloud \
  --tags "$TAG" \
  --metadata-from-file "startup-script=$DIR/startup.sh,verdaccio-config=$DIR/config.yaml"

echo "== ファイアウォール: Google 公開レンジからの tcp:4873 を許可 =="
# Google の公開IPレンジを取得（ipv4）。1ルールあたり最大256レンジのため分割する。
TMP="$(mktemp -d)"
curl -s https://www.gstatic.com/ipranges/goog.json \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);for(const p of j.prefixes){if(p.ipv4Prefix)console.log(p.ipv4Prefix)}})' \
  > "$TMP/ranges.txt"
split -l 256 "$TMP/ranges.txt" "$TMP/chunk-"
i=0
for f in "$TMP"/chunk-*; do
  i=$((i+1))
  ranges="$(paste -sd, "$f")"
  gcloud compute firewall-rules create "${TAG}-allow-${i}" \
    --project "$PROJECT" --allow tcp:4873 --target-tags "$TAG" \
    --source-ranges "$ranges" >/dev/null
  echo "  firewall ${TAG}-allow-${i}: $(wc -l < "$f" | tr -d ' ') レンジ許可"
done
rm -rf "$TMP"

# 運用者（このマシン）の現在のグローバルIPも許可する。publish/疎通確認をラップトップから行うため。
# Google レンジには含まれないので別ルールで追加する。IPが変わったら再作成する（teardown で消える）。
MYIP="$(curl -s https://checkip.amazonaws.com | tr -d '[:space:]')"
if [ -n "$MYIP" ]; then
  gcloud compute firewall-rules create "${TAG}-allow-admin" \
    --project "$PROJECT" --allow tcp:4873 --target-tags "$TAG" \
    --source-ranges "${MYIP}/32" >/dev/null
  echo "  firewall ${TAG}-allow-admin: 運用者IP ${MYIP}/32 を許可"
fi

IP="$(gcloud compute instances describe "$NAME" --project "$PROJECT" --zone "$ZONE" \
  --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"
echo
echo "完了。レジストリ URL: http://$IP:4873/"
echo "次の手順:"
echo "  1) 起動待ち（1〜2分）後、good を publish:  REG=http://$IP:4873/ gce/publish.sh good"
echo "  2) frontend/.npmrc の registry を上記 URL にする（例: registry=http://$IP:4873/）"
echo "  3) デモ当日、悪性のバージョンを publish:              REG=http://$IP:4873/ gce/publish.sh evil"
echo "  片付け: PROJECT=$PROJECT ZONE=$ZONE gce/teardown.sh"
