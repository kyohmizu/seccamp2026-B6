# 演習09: Policy-as-Code でデプロイポリシーを拡張する

演習05で作成した Binary Authorization ポリシーをコード化し、管理・拡張します。単一のアテスター要求にとどまらず、複数アテスターによる検証や SLSA レベルに応じたチェックへと適用範囲を広げます。

> [!NOTE]
> Binary Authorization ポリシーは Google Cloud プロジェクト単位のシングルトンリソースです。単一プロジェクトを共有する環境ではプロジェクト全体に直ちに適用される共通設定となるため、まずは監査モード（`DRYRUN_AUDIT_LOG_ONLY`）で動作を検証し、演習終了後はポリシーを `ALWAYS_ALLOW` へ復元してください。

## 関連
- 2-2「対策選定の観点」（共通基盤で強制、Policy-as-Code）
- 演習05の続き

## 課題
1. Binary Authorization ポリシー（YAML）を Git 管理し、Terraform またはスクリプト経由で適用してください（手動設定に依存しない構成にします）。
2. ポリシーを拡張してください（Cloud Run で適用可能な範囲）。
   - **複数アテスターの必須化**（`requireAttestationsBy` に複数指定。例: 正規ビルドの証明＋人手のセキュリティレビュー承認を AND で必須化）
   - **（GKE 向けの発展）** 名前空間・クラスタ別のルール（`clusterAdmissionRules`）や Continuous Validation の SLSA チェック等。これらは GKE の機能であり、Cloud Run のデプロイ時ポリシーには適用されません。

<details>
<summary>ヒント</summary>

- ポリシーは `google_binary_authorization_policy`（Terraform）で管理できます。
- **段階的な導入**: 最初は `DRYRUN_AUDIT_LOG_ONLY`（監査モード）で影響を確認し、問題がなければ `ENFORCED_BLOCK_AND_AUDIT_LOG`（強制モード）へ移行します。
- Binary Authorization 以外にも、OPA/Gatekeeper などの汎用ポリシーエンジンや、GitLab の Pipeline Execution Policies といった各種 Policy-as-Code の手法が存在します。

</details>

## 検証
- ポリシーがコードから確実に適用され、仮に開発者がリポジトリ内のパイプライン定義（`.yaml`）等を変更してもポリシー検証を回避できない構造になっていることを確認してください。
