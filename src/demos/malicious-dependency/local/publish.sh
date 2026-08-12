#!/usr/bin/env bash
# expense-format の指定バージョンを Verdaccio に publish する。
#   publish.sh good   → 1.0.0（正規のバージョン）
#   publish.sh evil   → 1.0.1（悪性シミュレーション）
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REG="http://localhost:4873"

case "${1:-}" in
  good) PKG="$DIR/../registry/expense-format-good" ;;
  evil) PKG="$DIR/../registry/expense-format-evil" ;;
  *) echo "使い方: publish.sh good|evil" >&2; exit 1 ;;
esac

cd "$PKG"
# Verdaccio 側で expense-format は publish:$all（匿名可）だが、npm クライアントはトークン行を要求するため用意する。
echo "//localhost:4873/:_authToken=demo-token" > .npmrc
trap 'rm -f "$PKG/.npmrc"' EXIT
npm publish --registry "$REG" 2>&1 | tail -3 || true
echo "publish 完了: expense-format@$(node -p "require('./package.json').version") ($1)"
