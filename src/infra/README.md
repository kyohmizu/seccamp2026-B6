# infra（Terraform）

環境を再現可能にする IaC です。1プロジェクトに実行者の環境を `for_each` でまとめて作成します。

## 構成
- ルート（`main.tf` / `variables.tf` / `outputs.tf`）… `app_count` から `app-01..` を生成（または `environments` の明示指定）し、環境ごとに1セット作成します。
- `modules/environment/` … 1環境分（AR ＋ SA×2 ＋ Cloud Run×2 ＋ IAM）。全リソースに `project` を明示。
- `modules/source-trigger/` … SCM＋Cloud Build トリガー（疎結合の差し替え点。GitHub↔SSM 切替はここだけ）。`github_repo` を指定した env だけ作られます。

> Binary Authorization を有効化する場合、ポリシーはプロジェクト単位のシングルトンのため、1プロジェクト共有では全 env に影響します（実行者ごとに独立した状態は持てません）。この点に注意してください。

## 環境の指定
通常は `google_project` / `app_count` に加え、GitHub 連携に必要な `github_owner` / `connection_name` / `npm_registry` を指定します。1プロジェクトに `app-01..app-NN` を GitHub 連携付き（push / PR / deploy トリガー）で生成し、各環境はキー（＝`name_prefix`）で分離されます。事前に host connection を gcloud で作成・OAuth 認可しておく必要があります（下記「source-trigger を含める場合」参照）。
```hcl
google_project  = "your-project-id"
app_count       = 10
github_owner    = "your-org"           # 個人アカウント名 or 組織名
connection_name = "flowpay-github"     # gcloud で作成・OAuth 認可済みの接続名
npm_registry    = "http://<IP>:4873/"  # 演習用 Verdaccio（frontend の expense-format 解決に使用）
```
`app-NN` はそれぞれ GitHub リポジトリ `<github_owner>/seccamp2026-B6-app-NN` を対象にします。トリガーを持たない env や別プロジェクト構成など個別設定が必要な場合は、`app_count = 0` にして `environments` を明示します。記述例は `terraform.tfvars.example` を参照してください。

> 単一プロバイダで別プロジェクトも書ける理由: モジュール内の全リソースに `project = var.project_id` を明示しているため、プロバイダを env ごとに増やさずに別プロジェクトへ書き分けられます。デプロイに使用する ID は、対象の全プロジェクトに権限（`serviceusage.services.enable` 等）が必要です。

## 使い方
```
cd src/infra
cp terraform.tfvars.example terraform.tfvars   # google_project / app_count / github_owner / connection_name / npm_registry を編集
terraform init
terraform plan
terraform apply
terraform output environments                  # 各 env の URL / AR / SA を確認
```
実イメージのビルド＆デプロイや動作検証までの通し手順は [../docs/provisioning.md](../docs/provisioning.md) を参照してください。

## source-trigger を含める場合
`app_count` のループは各 env にトリガー（push / PR / deploy）を自動で作ります（`environments` 明示でも該当 env に `github_repo` 等を足せば同様）。ただし GitHub の host connection は OAuth 認可が必要なため、対象プロジェクトごとに gcloud で1回だけ手動作成しておきます（`modules/source-trigger/main.tf` 冒頭のコメント参照）。最小権限のトリガー SA を使用するには、各プロジェクトの Cloud Build サービスエージェント(P4SA) にその SA への `roles/iam.serviceAccountTokenCreator` が必要です。
