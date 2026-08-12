#!/usr/bin/env bash
# provision.sh で作った VM とファイアウォールを削除する。
# 使い方: PROJECT=YOUR_PROJECT ZONE=asia-northeast1-b gce/teardown.sh
set -euo pipefail
PROJECT="${PROJECT:?PROJECT を指定してください}"
ZONE="${ZONE:-asia-northeast1-b}"
NAME="${NAME:-verdaccio-demo}"
TAG="verdaccio-demo"

gcloud compute instances delete "$NAME" --project "$PROJECT" --zone "$ZONE" --quiet || true
for r in $(gcloud compute firewall-rules list --project "$PROJECT" \
    --filter="name~^${TAG}-allow-" --format='value(name)'); do
  gcloud compute firewall-rules delete "$r" --project "$PROJECT" --quiet || true
  echo "  削除: $r"
done
echo "片付け完了"
