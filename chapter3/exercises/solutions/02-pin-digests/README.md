# 解答: コンテナイメージ digest の固定

`<DIGEST>` 表記部分は、[resolve-digests.cloudbuild.yaml](./resolve-digests.cloudbuild.yaml) 等の自動解決スクリプトを用いて取得した実際の SHA-256 digest 値へ置換します。
digest 値はイメージのビルドおよび更新に伴い変動するため、本文書では記述フォーマットの規定のみを示します（実作業時は固定実行時点の最新値を記述します）。固定適用後の完成形定義ファイル群は [pinned/](./pinned/) ディレクトリ内に配置されています。

## 可変タグ参照箇所の特定と洗い出し
固定対象となる可変タグによるコンテナイメージ参照箇所は以下の通りです。
- **Dockerfile 内の `FROM` 句**
  - `backend/Dockerfile`: `golang:1.23`, `gcr.io/distroless/static-debian12:nonroot`
  - `frontend/Dockerfile`: `node:22-slim`
- **`pipelines/cloudbuild.yaml` 内のステップ `name` フィールド**
  - `gcr.io/cloud-builders/docker`、`node:22-slim`（`frontend-deps` ステップ）
- 演習内で使用するその他各種ビルドステップ（`aquasec/trivy`、`gcr.io/google.com/cloudsdktool/cloud-sdk`、`cosign` 等）におけるイメージ参照も同様に固定化の対象となります。

## backend/Dockerfile（固定後）
```dockerfile
FROM golang:1.23@sha256:<DIGEST> AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /server .

FROM gcr.io/distroless/static-debian12:nonroot@sha256:<DIGEST>
COPY --from=build /server /server
USER nonroot
ENTRYPOINT ["/server"]
```

## frontend/Dockerfile（固定後・抜粋）
依存パッケージは CI パイプラインの先行ステップ（`frontend-deps`）にて導入済みのため、実行用イメージは `node_modules` を配置するのみの単一ステージ構成となります。
```dockerfile
FROM node:22-slim@sha256:<DIGEST>
WORKDIR /app
COPY package.json ./
COPY node_modules ./node_modules
COPY server.js ./
COPY public ./public
CMD ["node", "server.js"]
```

## pipelines/cloudbuild.yaml（固定後・抜粋）
```yaml
steps:
  - id: build-backend
    name: gcr.io/cloud-builders/docker@sha256:<DIGEST>
    args: ['build', '-t', '...backend:latest', 'backend']
```

## アプリケーション依存パッケージの固定との関係
ベースイメージの digest 固定と対をなす、アプリケーション依存パッケージの決定論的固定（`package-lock.json` ＋ `npm ci`）については [演習03: 依存パッケージの固定](../../03-npm-ci-lockfile.md) にて解説します。本演習ではコンテナイメージの digest 固定に特化して検証を行います。

## ポイント
- **タグ＋digest の併記形式**（`golang:1.23@sha256:...`）を採用することにより、人間にとっては対象バージョンが直感的に識別可能であり、同時に CI/CD システム側では digest による不変の固定が実現されます。
- digest による固定は「既存タグの指すコンテンツが後から改ざん・変更された場合であっても、参照されるイメージ実体は変化しない」ことを技術的に保証します。tj-actions のインシデント事例は**既存タグの参照先が悪性コミットへ書き換えられた**攻撃手法であったため、digest（またはコミット SHA）による完全固定を適用していたユーザーは影響を回避できました。
- イメージの固定化は、ビルド処理における**決定性・再現性**（同一の入力から常に同一の出力成果物を得る性質）の確保に直接寄与します。コンテナイメージの digest 固定と npm の lockfile は、双方ともに「ビルド入力を一意かつ決定論的に固定する」ための強力なセキュリティ対策です。
- 固定化運用における課題は「依存関係が更新されず古いままで放置されるリスク」です。**Renovate や Dependabot 等の依存関係自動更新ツールを活用して digest やパッケージ依存を定期更新**し、ビルドの決定性確保とセキュリティアップデートへの追従を高度に両立させます（発展課題）。

## 動作確認
- 各 Dockerfile の `FROM` 句および `pipelines/cloudbuild.yaml` 内のステップ `name` フィールドが、可変タグではなく `@sha256:...` 形式で固定されていることを確認します。
- 完全固定を適用した状態で `gcloud builds submit` コマンドを実行し、ビルド処理が正常に成功することを確認します。
- **digest 値はイメージのビルドに伴い動的に変化します。** 実際の固定作業時は、`resolve-digests.cloudbuild.yaml` 等を実行して最新の digest 値をご自身で取得・転記してください（`pinned/` 配下の設定値も取得時点の記録です）。
