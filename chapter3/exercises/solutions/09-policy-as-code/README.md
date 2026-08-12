# 解答: Policy-as-Code でデプロイポリシーを拡張する

演習05で作成した Binary Authorization ポリシーを、手動の `import` 処理ではなく Git 管理および Terraform による宣言的な記述で適用します。設定変更に対する事前のコードレビューと、変更履歴の再現性を確保します。あわせて、監査モード（DRYRUN）による段階的導入および複数アテスターへの拡張を扱います。

- [binauthz-policy-dryrun.yaml](./binauthz-policy-dryrun.yaml) — 段階的導入用の監査モード定義（`enforcementMode: DRYRUN_AUDIT_LOG_ONLY`）
- [binauthz-policy-multi.yaml](./binauthz-policy-multi.yaml) — 複数アテスター必須化定義（`gcloud import` 用）
- [main.tf](./main.tf) — ポリシーおよびカスタムアテスターを管理する Terraform 設定

## ポリシーのコード管理（Policy-as-Code の実践）

ポリシー定義を Git で管理し、適用処理を自動化・コマンド化します。`gcloud` コマンドで import を実行する場合（`chapter3/exercises` ディレクトリから実行）:

```bash
sed "s/<PROJECT>/$PROJECT/" solutions/05-provenance-binauthz/binauthz-policy.yaml > /tmp/binauthz.yaml
gcloud container binauthz policy import /tmp/binauthz.yaml --project $PROJECT
```

Terraform で管理する場合は [main.tf](./main.tf) の `google_binary_authorization_policy` リソースとしてポリシーを記述し、`terraform plan` で差分をレビューした上で `terraform apply` を実行します。ポリシー定義そのものがバージョン管理およびピアレビューの対象となります。

```bash
terraform init
terraform plan  -var project_id=$PROJECT -var security_review_public_key_pem="$(cat key.pub)"
terraform apply -var project_id=$PROJECT -var security_review_public_key_pem="$(cat key.pub)"
```
`key.pub` ファイルは「ポリシーの拡張」ステップで作成する security-review アテスター用の公開鍵です。単一アテスター（`built-by-cloud-build`）のみで運用する場合は、`main.tf` から `security_review` アテスターと `require_attestations_by` の該当行を削除することで `key.pub` の指定は不要となります。

## 段階的導入（DRYRUN → ENFORCED）

監査モードと強制モードの切り替えは **`enforcementMode`** フィールドで行います（`evaluationMode` は `REQUIRE_ATTESTATION` の状態を維持します）。初期導入時は [binauthz-policy-dryrun.yaml](./binauthz-policy-dryrun.yaml)（`DRYRUN_AUDIT_LOG_ONLY`）を適用し、既存のデプロイ処理への影響を確認します。DRYRUN モードでは、検証条件を満たさないイメージのデプロイも**ブロックされず、監査ログへの記録のみ**が実行されます。既存構成への影響がないことを確認した後に、`enforcementMode` を `ENFORCED_BLOCK_AND_AUDIT_LOG`（演習05の [binauthz-policy.yaml](../05-provenance-binauthz/binauthz-policy.yaml)）へ変更して強制ブロック運用へ移行します。

## ポリシーの拡張（複数アテスターの必須化）

Cloud Run 向けのポリシー設定では `requireAttestationsBy` を**リスト形式**で指定可能であり、複数アテスターによる attestation を **AND 条件**で必須化できます。[binauthz-policy-multi.yaml](./binauthz-policy-multi.yaml) では、`built-by-cloud-build`（Cloud Build による正規ビルド証明）に加えて `security-review`（手動でのセキュリティレビュー承認）の attestation を必須としています。両方の証明が揃わない場合はデプロイが実行されません。

なお、`built-by-cloud-build` は Cloud Build が provenance 生成（`requestedVerifyOption: VERIFIED`）を有効化した時点で**自動生成**されるアテスターであるため、コード上で新規作成は行わず名前で参照します。コード内で新規作成対象となるのは2つ目の `security-review` アテスターのみです（`main.tf` の `google_container_analysis_note` ＋ `google_binary_authorization_attestor` リソース）。

2つ目のアテスターである `security-review` は、署名鍵の準備 → アテスターの作成 → レビュー実行時の attestation 付与、の順序で構成します。

1. **署名鍵の作成（Cloud KMS）**: 非対称署名鍵を作成し、公開鍵をファイル出力して Terraform に渡します（`key.pub`）。
   ```bash
   gcloud kms keyrings create binauthz --location global --project $PROJECT
   gcloud kms keys create security-review --keyring binauthz --location global \
     --purpose asymmetric-signing --default-algorithm ec-sign-p256-sha256 --project $PROJECT
   gcloud kms keys versions get-public-key 1 --key security-review --keyring binauthz \
     --location global --project $PROJECT --output-file key.pub
   ```
2. **アテスターおよびポリシーの作成**: `key.pub` を指定して「ポリシーのコード管理」の `terraform apply` を実行します（[main.tf](./main.tf) 内の `google_container_analysis_note`、`google_binary_authorization_attestor`、およびポリシーが作成されます）。
3. **レビュー承認（attestation の付与）**: レビュー担当者は検証・承認したコンテナイメージに対し、KMS 鍵を用いて attestation を作成・付与します。本データが存在しない場合（`built-by-cloud-build` の attestation のみの場合）はデプロイが拒否されます。
   ```bash
   gcloud container binauthz attestations sign-and-create \
     --artifact-url=<IMG>@<digest> \
     --attestor security-review --attestor-project $PROJECT \
     --keyversion projects/$PROJECT/locations/global/keyRings/binauthz/cryptoKeys/security-review/cryptoKeyVersions/1
   ```

## GKE 向けの拡張機能（Cloud Run では対象外）

本演習の対象である Cloud Run のデプロイ時ポリシーでは、以下の機能は適用対象外となります（いずれも GKE 向けの機能となります）。

- **名前空間・クラスタ別の判定ルール**: `clusterAdmissionRules` は GKE クラスタ単位の評価ルールであり、Cloud Run には該当する概念が存在しません。
- **SLSA ビルドレベルに応じた検証**: SLSA チェック機能は Binary Authorization の **Continuous Validation（CV）** に属する機能であり、GKE クラスタ上の Pod を対象とします。Cloud Run のデプロイ時ポリシー（本演習における classic policy）の仕様には含まれません。

## 動作確認

- `gcloud container binauthz policy export` で取得した現在のポリシー構成が、Git 上の定義ファイル（または Terraform のステート情報）の内容と一致することを確認します（宣言的コードからの適用検証）。
- 開発者が個別の CI/CD パイプライン定義（`cloudbuild.yaml` 等）を改変した場合であっても、プロジェクト単位で強制されるデプロイ検証ポリシーを回避できないことを確認します（未検証イメージのデプロイ拒否動作の確認）。
- DRYRUN モードの適用時は、未検証イメージのデプロイが**ブロックされず**、監査ログへの記録のみが行われること（導入時の影響範囲を事前評価できる挙動）を確認します。
