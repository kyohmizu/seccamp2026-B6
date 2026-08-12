#!/usr/bin/env bash
# Verdaccio とモック攻撃者サーバを停止し、生成物を削除する。
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

docker rm -f flowpay-verdaccio >/dev/null 2>&1 || true
pkill -f "verdaccio@6" 2>/dev/null || true
pkill -f "mock-attacker/server.js" 2>/dev/null || true
rm -f "$DIR"/.work-*.log
rm -rf "$DIR/storage" "$DIR/verdaccio/storage"
rm -f "$(node -e 'console.log(require("os").tmpdir())')/flowpay-demo-PWNED-install.json" 2>/dev/null || true
echo "停止・クリーンアップ完了"
