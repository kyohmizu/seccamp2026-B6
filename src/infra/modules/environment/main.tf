# 1 利用者/グループ分の環境（AR ＋ SA ＋ Cloud Run ×2 ＋ IAM）。
# 全リソースに project を明示するため、単一プロバイダのまま
#   ・別プロジェクト方式（env ごとに project_id を変える）
#   ・共有プロジェクト方式（project_id 共通・name_prefix で分離）
# の両方を同じコードで扱える。

locals {
  ar_host = "${var.region}-docker.pkg.dev"
  repo_id = coalesce(var.repo_id, var.name_prefix)
}

# --- APIs ---
resource "google_project_service" "apis" {
  for_each = toset([
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "binaryauthorization.googleapis.com",
    "containeranalysis.googleapis.com",
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# --- Artifact Registry ---
resource "google_artifact_registry_repository" "flowpay" {
  project       = var.project_id
  repository_id = local.repo_id
  location      = var.region
  format        = "DOCKER"
  description   = "B6 handson images (${var.name_prefix})"
  depends_on    = [google_project_service.apis]
}

# --- Service Accounts（最小権限・サービス分離） ---
resource "google_service_account" "backend" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-backend-sa"
  display_name = "FlowPay backend (${var.name_prefix})"
}

resource "google_service_account" "frontend" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-frontend-sa"
  display_name = "FlowPay frontend (${var.name_prefix})"
}

# --- Cloud Run: backend（private） ---
resource "google_cloud_run_v2_service" "backend" {
  project             = var.project_id
  name                = "${var.name_prefix}-backend"
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL" # ネットワークは開くが、認証はIAMで必須（allUsersを付与しない＝private）

  template {
    service_account = google_service_account.backend.email
    # 経費データをインメモリで保持するため単一インスタンスに固定する。
    # スケールアウトすると POST を受けたインスタンスと GET を受けるインスタンスで内容が分裂するのを防ぐ。
    scaling {
      max_instance_count = 1
    }
    containers {
      image = var.bootstrap_image
    }
  }

  # 実イメージはパイプラインが更新するため、image は Terraform 管理外にする
  lifecycle {
    ignore_changes = [template[0].containers[0].image, client, client_version]
  }
  depends_on = [google_project_service.apis]
}

# --- Cloud Run: frontend（private） ---
resource "google_cloud_run_v2_service" "frontend" {
  project             = var.project_id
  name                = "${var.name_prefix}-frontend"
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.frontend.email
    containers {
      image = var.bootstrap_image
      env {
        name  = "BACKEND_URL"
        value = google_cloud_run_v2_service.backend.uri
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image, client, client_version]
  }
  depends_on = [google_project_service.apis]
}

# --- IAM: frontend SA が backend を invoke できる（サービス間認証） ---
resource "google_cloud_run_v2_service_iam_member" "frontend_invokes_backend" {
  project  = var.project_id
  name     = google_cloud_run_v2_service.backend.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.frontend.email}"
}

# --- IAM: 管理者/利用者本人が frontend を invoke（proxy で閲覧するため） ---
resource "google_cloud_run_v2_service_iam_member" "admin_invokes_frontend" {
  for_each = toset(var.members)
  project  = var.project_id
  name     = google_cloud_run_v2_service.frontend.name
  location = var.region
  role     = "roles/run.invoker"
  member   = each.value
}

# --- Service Account: deploy 専用（build SA とは分離＝権限分離） ---
resource "google_service_account" "deploy" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-deploy-sa"
  display_name = "FlowPay deploy (${var.name_prefix})"
}

# deploy SA: Cloud Run サービスを更新できる
resource "google_project_iam_member" "deploy_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.deploy.email}"
}

# deploy SA: ビルドログを Cloud Logging に書く（CLOUD_LOGGING_ONLY）
resource "google_project_iam_member" "deploy_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.deploy.email}"
}

# deploy SA: デプロイ時に AR のイメージを参照できる（Cloud Run デプロイに必要）
resource "google_artifact_registry_repository_iam_member" "deploy_ar_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.flowpay.location
  repository = google_artifact_registry_repository.flowpay.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.deploy.email}"
}

# deploy SA: runtime SA(backend/frontend) として動作させるための actAs（Cloud Run デプロイに必須）
resource "google_service_account_iam_member" "deploy_actas_backend" {
  service_account_id = google_service_account.backend.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deploy.email}"
}
resource "google_service_account_iam_member" "deploy_actas_frontend" {
  service_account_id = google_service_account.frontend.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deploy.email}"
}

# 注: Binary Authorization は baseline では有効化しない（＝未検証イメージも通る安全でない状態）。
#     デプロイ時検証は演習で有効化する。
#     ※ BinAuthz ポリシーはプロジェクト単位（シングルトン）。共有プロジェクト方式で演習05を使用すると
#       env 間で干渉するため、その場合は per-service の platform policy に切り替えること（別プロジェクト方式なら不要）。

# --- 他モジュール（source-trigger の deploy トリガー）へ渡す値 ---
output "deploy_sa_email" {
  value = google_service_account.deploy.email
}
output "backend_service_name" {
  value = google_cloud_run_v2_service.backend.name
}
output "frontend_service_name" {
  value = google_cloud_run_v2_service.frontend.name
}
