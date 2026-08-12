#!/usr/bin/env bash
# Verdaccio（公開npmの代役）とモック攻撃者サーバを起動する。
# Docker があれば Docker、無ければ npx で Verdaccio を立てる。
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REG="http://localhost:4873"

# モック攻撃者（既に起動していなければ）
if ! pgrep -f "mock-attacker/server.js" >/dev/null 2>&1; then
  node "$DIR/mock-attacker/server.js" >"$DIR/.work-mock.log" 2>&1 &
  sleep 1
  echo "mock attacker 起動（受信ログ: $DIR/.work-mock.log）"
else
  echo "mock attacker は既に起動しています"
fi

# Verdaccio
if curl -s -o /dev/null "$REG"; then
  echo "Verdaccio は既に起動しています: $REG"
else
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    docker run -d --rm --name flowpay-verdaccio -p 4873:4873 \
      -v "$DIR/verdaccio/config.yaml:/verdaccio/conf/config.yaml" \
      verdaccio/verdaccio:6 >/dev/null
    echo "Verdaccio(docker) 起動中…"
  else
    npx --yes verdaccio@6 --config "$DIR/verdaccio/config.yaml" --listen 4873 \
      >"$DIR/.work-verdaccio.log" 2>&1 &
    echo "Verdaccio(npx) 起動中…（ログ: $DIR/.work-verdaccio.log）"
  fi
  for _ in $(seq 1 30); do curl -s -o /dev/null "$REG" && break; sleep 1; done
  if curl -s -o /dev/null "$REG"; then
    echo "Verdaccio 準備完了: $REG"
  else
    echo "Verdaccio 起動に失敗しました。ログを確認してください。" >&2
    exit 1
  fi
fi

echo
echo "次: local/demo.sh で攻撃デモ、local/defenses.sh で対策の実演。"
echo "   （一歩ずつ止めたい場合は PAUSE=1 を付ける: PAUSE=1 local/demo.sh）"
