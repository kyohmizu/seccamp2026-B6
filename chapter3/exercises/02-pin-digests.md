# 演習02: イメージ digest 固定

ビルド処理で参照するコンテナイメージを、可変タグ（`latest` や `:1.23`）ではなく digest（`@sha256:...`）で固定します。可変タグは後から同一タグの指すコンテンツを書き換えることが可能なため、digest による固定を行わない場合、意図しないイメージや改ざんされたイメージが使用されるリスクが残ります。

可変タグによるイメージ参照は、Dockerfile 内の `FROM` 句および `pipelines/cloudbuild.yaml` 内の step `name` フィールドに存在します。これら2箇所を対象として、まずは可変タグで参照されている箇所を正確に洗い出します。

## 関連
- 1-1 tj-actions/changed-files。タグの書き換えによって悪性コードが引き込まれた事案ですが、コミット SHA や digest で固定していた利用者は影響を受けませんでした。
- SLSA（ビルドの再現性・改ざん耐性の確保）

## 課題
1. パイプライン定義と Dockerfile から、可変タグでイメージを参照している箇所をすべて洗い出してください。
2. 各イメージの最新の digest（ハッシュ値）を取得・解決してください。
3. Dockerfile の `FROM` 句およびパイプラインの step `name` を、`@sha256:...` 形式の digest を用いて固定してください（可読性とトレーサビリティのため、タグ＋digest の併記形式とします）。

<details>
<summary>ヒント</summary>

```bash
# digest の解決（いずれかの方法を実行）
crane digest golang:1.23
docker buildx imagetools inspect node:22-slim --format '{{.Manifest.Digest}}'

IMG=$REGION-docker.pkg.dev/$PROJECT/flowpay
gcloud artifacts docker images describe $IMG/backend:latest --format='value(image_summary.digest)'

# 一括解決スクリプト（Cloud Build 上で crane を使用して解決する）
gcloud builds submit --no-source --config solutions/02-pin-digests/resolve-digests.cloudbuild.yaml
```
記述方法（タグ＋digest の併記形式）:
```dockerfile
FROM golang:1.23@sha256:<DIGEST> AS build
```
```yaml
steps:
  - name: gcr.io/cloud-builders/docker@sha256:<DIGEST>
```

</details>

## 検証
- すべての参照を digest 固定した状態で `gcloud builds submit` を実行し、ビルドが正常に成功することを確認してください。

## 発展
- **固定と自動更新の両立**: digest による固定を実施すると、参照イメージが古い状態で放置されやすくなる課題が生じます。Renovate や Dependabot などの自動更新ツールを活用して digest を定期更新する仕組みを導入し、再現性の確保とセキュリティ更新の追従を両立させます。
- サードパーティ製 Action（GitHub Actions を使用する場合）におけるコミット SHA による完全固定化の適用を検討します。
