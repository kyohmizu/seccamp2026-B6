#!/bin/bash
# GCE(COS) VM の startup-script。Verdaccio をコンテナで起動する。
# 設定はメタデータ verdaccio-config から取得し、storage はホストに置いて再起動でも残す。
set -e

mkdir -p /home/verdaccio/storage
# Verdaccio コンテナは uid 10001 で動くので storage を書き込み可能にする
chown -R 10001:10001 /home/verdaccio/storage

# 設定ファイルをメタデータから取り出す
curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/attributes/verdaccio-config" \
  > /home/verdaccio/config.yaml

# 既存があれば止めてから起動（再実行に耐える）
docker rm -f verdaccio >/dev/null 2>&1 || true
docker run -d --name verdaccio --restart always \
  -p 4873:4873 \
  -v /home/verdaccio/config.yaml:/verdaccio/conf/config.yaml \
  -v /home/verdaccio/storage:/verdaccio/storage \
  verdaccio/verdaccio:6
