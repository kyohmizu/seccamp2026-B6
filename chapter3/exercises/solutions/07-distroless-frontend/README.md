# 解答: frontend の最小イメージ化

frontend の実行用コンテナイメージを distroless の Node.js ランタイムへ置き換えます。依存パッケージは CI パイプラインの先行ステップ（`frontend-deps`）にて導入済みのため、実行用イメージは `node_modules` を配置するのみの単一ステージ構成となります。

## frontend/Dockerfile（最小化後）
```dockerfile
FROM gcr.io/distroless/nodejs22-debian12
WORKDIR /app
COPY package.json ./
COPY node_modules ./node_modules
COPY server.js ./
COPY public ./public
CMD ["server.js"]
```

## ポイント
- distroless の Node.js イメージにはシェル（`sh` / `bash`）が含まれないため、`CMD` には実行対象スクリプトのパスを直接渡します（`node` バイナリはイメージのエントリポイント側に定義済みです）。
- 依存パッケージは `frontend-deps` ステップの `npm ci` で用意された `node_modules` ディレクトリを `COPY` します。
- distroless の Node.js コンテナイメージは **npm 自体を同梱しません**。そのため OS パッケージ層の削減に加えて、`node:22-slim` 等に同梱されている npm や corepack 由来の `node_modules` に起因する脆弱性（Trivy が node-pkg として検出する項目）も除去されます（アプリケーション本体の `node_modules` は影響を受けません）。
- さらにイメージサイズおよび脆弱性を削減する場合は、Chainguard が提供する最小 Node.js イメージ（Wolfi ベース）等も選択肢となります。

## 動作確認
```bash
IMG=$REGION-docker.pkg.dev/$PROJECT/flowpay
# 最小化した Dockerfile でビルド・push した後、変更前後で件数を比較
trivy image --severity HIGH,CRITICAL $IMG/frontend:latest
```
- distroless 化の実施後は OS パッケージ層に起因する脆弱性が大幅に削減され、従来の `node:22-slim` 版と比較して HIGH/CRITICAL 重大度の検出件数が減少することを確認します（検出される脆弱性の大半は OS パッケージ由来であるため、含まれるパッケージの母数を絞り込むことで件数が減少します）。
- ビルドおよびデプロイの完了後、`gcloud run services proxy` コマンドを経由してフロントエンド Web UI が従来通り正常に表示・動作すること（アプリケーション機能に影響がないこと）を確認します。
