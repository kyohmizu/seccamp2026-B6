#!/bin/bash
# GCE(COS) VM の startup-script。攻撃者の受信サーバ(C2)をコンテナで起動する。
# server.js はメタデータ attacker-server から取得する。
set -e

mkdir -p /home/attacker
curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/attributes/attacker-server" \
  > /home/attacker/server.js

docker rm -f attacker-receiver >/dev/null 2>&1 || true
docker run -d --name attacker-receiver --restart always \
  -p 9099:9099 \
  -v /home/attacker/server.js:/app/server.js \
  -e HOST=0.0.0.0 -e PORT=9099 \
  node:22-slim node /app/server.js
