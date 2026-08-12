# 演習05: provenance ＋ Binary Authorization でデプロイ時検証

「Cloud Build が生成した（provenance が付いた）イメージだけをデプロイできる」状態にします。未検証のイメージは Cloud Run がデプロイ時に拒否します。取得時・ビルド時の対策に加えて、デプロイの段階でイメージを検証します。

> [!NOTE]
> Binary Authorization ポリシーは Google Cloud プロジェクト単位のシングルトンリソースです。単一プロジェクトを全参加者で共有する環境において本演習を実施する場合、ポリシー変更はプロジェクト全体へ直ちに適用される共有設定となり、参加者ごとに独立した状態を保持することはできません。他の参加者の実行環境へ影響を及ぼす点に十分留意してください。

- Cloud Build は `built-by-cloud-build` アテスターを自動作成し、ビルドしたイメージに attestation を自動付与します（`verified-builder` の KMS 鍵で署名）。
- Binary Authorization for Cloud Run は、デプロイ時にそのアテスターで検証します。条件を満たさないイメージは拒否します。

> [!NOTE]
> 用語: **provenance（来歴）** は「どのソースから・どのビルドで・どの入力で」作られたかの機械可読な記録、**attestation（アテステーション）** はその記録に署名して検証可能にしたもの、**attestor（アテスター）** はデプロイ時にその署名を検証する側（信頼する鍵を持つ検証者）です。

## 関連
- 1-1 TanStack（正当な provenance を持つ悪性）。署名 / provenance があっても万能ではないため、多層で重ねます。
- 2-2「デプロイ・実行時の検証と保護」（信頼を前提にせず、デプロイ時に検証する＝Verify, then Trust）

## 課題
1. ビルド側で provenance 生成を有効化してください。ビルドパイプライン（`pipelines/cloudbuild.yaml`）の `options` に `requestedVerifyOption: VERIFIED` を追加して再ビルドします。これで Cloud Build が `built-by-cloud-build` アテスターを作成し、ビルドしたイメージに attestation を付与します。
2. `built-by-cloud-build` アテスターの存在と、自分のイメージに attestation が付いたことを確認してください。
3. 生成された provenance を実際に取得し、記録内容を読み解いてください。
   ```bash
   gcloud artifacts docker images describe \
     ${REGION}-docker.pkg.dev/${PROJECT}/<リポジトリ>/<イメージ>@sha256:<digest> \
     --show-provenance --format=json
   ```
   Cloud Build は SLSA **v0.1 と v1.0 の両方**を生成・保存するため、`--show-provenance` は2エントリ返します（v0.1 は `intotoStatement`、v1.0 は `inTotoSlsaProvenanceV1` の下）。以下は **v1.0** の主なフィールドと意味です。
   - `predicateType`（`https://slsa.dev/provenance/v1`）: どの provenance 仕様に沿うか
   - `runDetails.builder.id`（`https://cloudbuild.googleapis.com/GoogleHostedWorker`）: 誰がビルドしたか（ビルダーの識別子）
   - `buildDefinition.externalParameters.buildConfigSource`（`repository`・`ref`・`path`）と `internalParameters` の `COMMIT_SHA`: どのソースの・どのコミットから作られたか
   - `buildDefinition.resolvedDependencies[]`（`uri` と `digest`）: 入力（ソースやベースイメージなど）の出所と digest
   - `runDetails.metadata`（`startedOn`・`finishedOn`・`invocationId`）: いつ・どの実行で作られたか
   - `subject`（`name` と `digest`）: この provenance が対象とする成果物（イメージ）

   「どのソースの・どのコミットから・どのビルダーで・どの入力によって、この digest のイメージになったか」を、1つの署名付き記録でたどれることを確認してください。
4. Binary Authorization ポリシーを `REQUIRE_ATTESTATION`（built-by-cloud-build）に設定してください。
5. deploy パイプライン（`pipelines/cloudbuild.deploy.yaml`）の `gcloud run services update` に `--binary-authorization=default` を追加し、実サービス（`app-<NN>`）を検証対象にしてください。次を確認します。
   - Cloud Build 製イメージ（provenance 付き）→ **実パイプラインのデプロイが許可される**
   - 未検証イメージ（例: `nginx`、attestation なし）を手動デプロイ → **拒否される**（パイプラインは検証済みイメージしか流さないため、拒否は手動で確認します）
6. 検証後、ポリシーを `ALWAYS_ALLOW` に戻してください（共有環境に影響を残さないため）。

## 検証
- Cloud Build 製イメージはデプロイでき、未検証イメージは次のように拒否されることを確認してください。
  ```
  Container image '...nginx@sha256:...' is not authorized by policy.
  denied by attestor .../built-by-cloud-build:
  No attestations found that were valid and signed by a key trusted by the attestor
  ```

## 発展
- breakglass（緊急時に Binary Authorization の検証をバイパスしてデプロイする仕組み）の運用を定め、使用を監査ログで追跡します。
