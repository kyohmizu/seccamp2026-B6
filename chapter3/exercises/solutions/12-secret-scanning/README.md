# 解答: Secret Scanning

- [cloudbuild.secret.yaml](./cloudbuild.secret.yaml) — Trivy の secret スキャナで、ソース（`fs`）とビルド済みイメージ（`image`）を検査する単体実行用の構成です。`gcloud builds submit` や手動トリガーで実行します。既存のビルドパイプライン（`pipelines/cloudbuild.yaml`）に組み込む場合は、push の前に `secret-scan-source` を、push の後にイメージスキャンを配置します。
- 初期導入は `--exit-code 0`（レポートのみ・ビルドは落とさない）です。検出でビルドを止める品質ゲートにするには `--exit-code 1` に変更します。

## コマンド手順

```bash
# 事前準備: export PROJECT=<your-google-cloud-project> REGION=asia-northeast1
IMG=$REGION-docker.pkg.dev/$PROJECT/flowpay

# ソースの secret スキャン（作業ツリー全体）
trivy fs --scanners secret .

# 検出確認: 実在しないダミーを一時的に追加してスキャン（確認後に削除）
#   例: ファイルに次の行を追加する
#     aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
trivy fs --scanners secret .

# イメージの secret スキャン
trivy image --scanners secret $IMG/frontend:latest
trivy image --scanners secret $IMG/backend:latest

# CI（Cloud Build）で単体実行する（リポジトリのルートで実行）
gcloud builds submit --config chapter3/exercises/solutions/12-secret-scanning/cloudbuild.secret.yaml .
```

## 期待される結果

- 通常の状態では secret は検出されない（クリーンな結果になる）。
- ダミーの認証情報を追加するとその箇所が検出され、削除すると再び検出されなくなる。
- 品質ゲート化（`--exit-code 1`）した場合、検出時に該当ステップが非ゼロ終了し、ビルドが失敗する。

## 補足

- Trivy の `fs` スキャンは作業ツリー（現在のファイル）を対象とし、git 履歴は検査しません。過去のコミットに含まれた秘密情報の検出には gitleaks（`gitleaks detect`）などの履歴スキャンを用います。
- 検出された認証情報は、リポジトリから削除するだけでなく必ず無効化・ローテーションします。コミット履歴やログから復元され得るため、削除だけでは漏洩が続きます。
