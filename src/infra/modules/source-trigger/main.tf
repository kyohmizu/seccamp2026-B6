# ソース(SCM) ＋ Cloud Build トリガー（構成A: GitHub）。
# ここだけ差し替えれば 構成B(Secure Source Manager) へ移行できる（疎結合の要）。
#
# ■ 接続(host connection) は OAuth 認可が必要なため gcloud で1回だけ作る（手動・ブラウザ操作あり）:
#     gcloud builds connections create github <connection_name> --region <region>
#     → 出力の actionUri を開き、Cloud Build GitHub App を対象リポジトリにインストール/認可
#   （個人アカウント配下のリポジトリなら個人アカウントにインストール。組織配下なら組織オーナー承認が必要な場合あり）
# ■ 以降、repository と trigger は Terraform で管理できる（このモジュール）。

variable "project_id" { type = string }
variable "region" {
  type    = string
  default = "asia-northeast1"
}
variable "connection_name" {
  type        = string
  default     = "flowpay-github"
  description = "gcloud で作成済みの host connection 名"
}
variable "github_owner" { type = string }
variable "github_repo" { type = string }
variable "repo_name" {
  type        = string
  description = "Artifact Registry のリポジトリ名（= cloudbuild の _REPO）。build/deploy 両トリガーに注入し、共有プロジェクトで env ごとに AR を分離する。"
}
variable "cloudbuild_config" {
  type        = string
  default     = null
  description = "トリガーが実行する cloudbuild 定義のパス。未指定なら src/pipelines/cloudbuild.trigger.yaml。実行者ごとの別リポジトリなら \"cloudbuild.yaml\"。"
}
variable "branch_pattern" {
  type    = string
  default = "^main$"
}
variable "service_account" {
  type        = string
  default     = null
  description = "トリガーのビルド実行SA（最小権限SA推奨）。例: projects/<p>/serviceAccounts/flowpay-build-sa@<p>.iam.gserviceaccount.com。未指定ならデフォルトのCloud Build SA。"
}
variable "substitutions" {
  type        = map(string)
  default     = {}
  description = "トリガーに渡す substitution（例: { _NPM_REGISTRY = \"http://<IP>:4873/\" }）。環境固有値は tfvars で渡す。"
}
variable "enable_pr_check" {
  type        = bool
  default     = true
  description = "pull_request でCIチェック（依存install＋検証ビルド）を実行するトリガーを作る。デモ: 更新PRがマージ前にランナー上で悪性依存を実行する様子を示せる。"
}
variable "pr_cloudbuild_config" {
  type        = string
  default     = null
  description = "PRチェック用 cloudbuild 定義のパス。未指定なら src/pipelines/cloudbuild.pr.yaml。"
}
variable "enable_deploy_trigger" {
  type        = bool
  default     = true
  description = "イメージ push（AR→Pub/Sub 通知）を契機に Cloud Run へデプロイするトリガーを作る。baseline は検証なしでデプロイする（検証は演習）。"
}
variable "deploy_cloudbuild_config" {
  type        = string
  default     = null
  description = "デプロイ用 cloudbuild 定義のパス。未指定なら src/pipelines/cloudbuild.deploy.yaml。"
}
variable "deploy_sa" {
  type        = string
  default     = null
  description = "デプロイトリガーの実行SA（build SA と分離した deploy SA、フルリソースパス）。未指定ならデフォルトのCloud Build SA。"
}
variable "service_backend" {
  type        = string
  default     = ""
  description = "デプロイ対象の backend Cloud Run サービス名（例: app-01-backend）。"
}
variable "service_frontend" {
  type        = string
  default     = ""
  description = "デプロイ対象の frontend Cloud Run サービス名。"
}
variable "deploy_branch" {
  type        = string
  default     = "main"
  description = "デプロイ用 cloudbuild 定義を取得するブランチ。"
}
# 注: 最小権限SAをトリガーで使用するには、Cloud Build サービスエージェント(P4SA)に
#     そのSAへの roles/iam.serviceAccountTokenCreator が必要（build SA・deploy SA とも。1回付与）。

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  connection_id = "projects/${var.project_id}/locations/${var.region}/connections/${var.connection_name}"
  # env が未指定(null)なら既定＝src/pipelines のパスにフォールバック
  cloudbuild_config     = coalesce(var.cloudbuild_config, "src/pipelines/cloudbuild.trigger.yaml")
  pr_cloudbuild_config  = coalesce(var.pr_cloudbuild_config, "src/pipelines/cloudbuild.pr.yaml")
  deploy_cloudbuild_cfg = coalesce(var.deploy_cloudbuild_config, "src/pipelines/cloudbuild.deploy.yaml")
  # ビルドSA（未指定ならデフォルトの Cloud Build SA）。ビルド末尾の publish 権限付与に使用する。
  build_sa_email = var.service_account != null ? split("/serviceAccounts/", var.service_account)[1] : "${data.google_project.this.number}@cloudbuild.gserviceaccount.com"
}

# GitHub リポジトリを接続に紐付け
resource "google_cloudbuildv2_repository" "repo" {
  name              = var.github_repo
  location          = var.region
  parent_connection = local.connection_id
  remote_uri        = "https://github.com/${var.github_owner}/${var.github_repo}.git"
}

# main への push でパイプラインを実行するトリガー
resource "google_cloudbuild_trigger" "push" {
  name     = "${var.github_repo}-push"
  location = var.region

  repository_event_config {
    repository = google_cloudbuildv2_repository.repo.id
    push {
      branch = var.branch_pattern
    }
  }

  filename        = local.cloudbuild_config
  service_account = var.service_account # 最小権限SA（未指定ならデフォルト）
  # _REPO（env の AR リポジトリ名）を注入し、共有プロジェクトでも env ごとに push 先 AR を分離する。
  # _NPM_REGISTRY 等に加え、deploy トリガー用トピックを _DEPLOY_TOPIC として渡す（ビルド末尾で publish）
  substitutions = merge(
    var.substitutions,
    { _REPO = var.repo_name },
    var.enable_deploy_trigger ? { _DEPLOY_TOPIC = google_pubsub_topic.image_pushed[0].name } : {},
  )
}

# pull_request でCIチェックを実行するトリガー（デモ: 更新PRがマージ前に実行される様子を示す）
resource "google_cloudbuild_trigger" "pull_request" {
  count    = var.enable_pr_check ? 1 : 0
  name     = "${var.github_repo}-pr"
  location = var.region

  repository_event_config {
    repository = google_cloudbuildv2_repository.repo.id
    pull_request {
      branch = var.branch_pattern
    }
  }

  filename        = local.pr_cloudbuild_config
  service_account = var.service_account # push 版と同じビルドSA（PRチェックが同じ権限で実行される点も論点）
  substitutions   = var.substitutions
}

# イメージ push を受け取る Pub/Sub トピック。
# ※ Artifact Registry の Pub/Sub 通知をこのトピックへ送る設定は gcloud で行う:
#     gcloud artifacts ... （AR の push を Pub/Sub へ通知）→ topic = このトピック
resource "google_pubsub_topic" "image_pushed" {
  count   = var.enable_deploy_trigger ? 1 : 0
  project = var.project_id
  name    = "${var.github_repo}-image-pushed"
}

# ビルドSA が、ビルド末尾でこのトピックへ publish できるようにする
resource "google_pubsub_topic_iam_member" "build_sa_publisher" {
  count   = var.enable_deploy_trigger ? 1 : 0
  project = var.project_id
  topic   = google_pubsub_topic.image_pushed[0].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${local.build_sa_email}"
}

# イメージ push を契機に Cloud Run へデプロイするトリガー（build とは別トリガー・別SA）。
# baseline は検証なし。attestation 検証step の追加やデプロイ時強制(BinAuthz)は演習で扱う。
resource "google_cloudbuild_trigger" "deploy" {
  count    = var.enable_deploy_trigger ? 1 : 0
  name     = "${var.github_repo}-deploy"
  location = var.region

  pubsub_config {
    topic = google_pubsub_topic.image_pushed[0].id
  }

  source_to_build {
    repository = google_cloudbuildv2_repository.repo.id
    ref        = "refs/heads/${var.deploy_branch}"
    repo_type  = "GITHUB"
  }
  git_file_source {
    path       = local.deploy_cloudbuild_cfg
    repository = google_cloudbuildv2_repository.repo.id
    revision   = "refs/heads/${var.deploy_branch}"
    repo_type  = "GITHUB"
  }

  service_account = var.deploy_sa # build SA と分離した deploy SA
  substitutions = {
    _REGION           = var.region
    _REPO             = var.repo_name
    _SERVICE_BACKEND  = var.service_backend
    _SERVICE_FRONTEND = var.service_frontend
  }
}

# --- 構成B（将来）: Secure Source Manager ---
# google_secure_source_manager_instance / repository ＋ 同等のトリガーに差し替える。
