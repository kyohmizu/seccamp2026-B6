# 一括プロビジョニングのルート。環境ごとに
#   ・modules/environment  … AR / SA / Cloud Run ×2 / IAM
#   ・modules/source-trigger（github_repo を指定した env だけ）… GitHub 接続＋トリガー
# を作る。app_count を指定すれば app-01.. を1プロジェクトに自動生成し（GitHub 連携付き）、
# 環境ごとに個別設定が必要な場合は environments を明示する。

locals {
  # app_count > 0 なら app-01.. を GitHub 連携付き（push/PR/deploy トリガーまで）で自動生成する。
  # 番号を env キー・name_prefix・repo_id・github_repo に貫通させ、共有プロジェクトでも AR/サービスを分離する。
  app_envs = {
    for i in range(var.app_count) : format("app-%02d", i + 1) => {
      project_id               = var.google_project
      name_prefix              = format("app-%02d", i + 1) # Cloud Run: app-01-frontend / -backend
      repo_id                  = format("app-%02d", i + 1) # Artifact Registry: app-01（_REPO はモジュールが注入）
      members                  = []                        # プロジェクトレベルの権限で invoke 可能なため env 単位の付与は不要
      github_owner             = var.github_owner
      github_repo              = format("seccamp2026-B6-app-%02d", i + 1)
      connection_name          = var.connection_name
      build_sa                 = var.app_build_sa   # 2nd-gen トリガーは SA 必須。既定は over-privileged な Compute SA（演習04 前の状態）
      cloudbuild_config        = "cloudbuild.yaml" # 演習用リポジトリはルート相対のパイプライン定義
      pr_cloudbuild_config     = "cloudbuild.pr.yaml"
      deploy_cloudbuild_config = "cloudbuild.deploy.yaml"
      enable_pr_check          = true
      enable_deploy_trigger    = true
      substitutions            = { _NPM_REGISTRY = var.npm_registry }
    }
  }

  # ループ生成分と、個別定義（environments。例: flowpay）をマージする。キーは衝突しない前提。
  environments = merge(local.app_envs, var.environments)
}

module "environment" {
  source   = "./modules/environment"
  for_each = local.environments

  project_id      = each.value.project_id
  region          = var.region
  name_prefix     = coalesce(each.value.name_prefix, each.key)
  repo_id         = each.value.repo_id
  bootstrap_image = var.bootstrap_image
  members         = each.value.members
}

# source-trigger は「github_repo を指定した env」だけ作る（接続の OAuth 認可を先に済ませておく必要あり）。
module "source_trigger" {
  source   = "./modules/source-trigger"
  for_each = { for k, v in local.environments : k => v if v.github_repo != null }

  project_id               = each.value.project_id
  region                   = var.region
  connection_name          = each.value.connection_name
  github_owner             = each.value.github_owner
  github_repo              = each.value.github_repo
  repo_name                = module.environment[each.key].repo_id
  service_account          = each.value.build_sa
  cloudbuild_config        = each.value.cloudbuild_config
  pr_cloudbuild_config     = each.value.pr_cloudbuild_config
  deploy_cloudbuild_config = each.value.deploy_cloudbuild_config
  enable_pr_check          = each.value.enable_pr_check
  enable_deploy_trigger    = each.value.enable_deploy_trigger
  substitutions            = each.value.substitutions

  # deploy トリガー用: environment が作る deploy SA と Cloud Run サービス名を渡す
  deploy_sa        = "projects/${each.value.project_id}/serviceAccounts/${module.environment[each.key].deploy_sa_email}"
  service_backend  = module.environment[each.key].backend_service_name
  service_frontend = module.environment[each.key].frontend_service_name

  depends_on = [module.environment]
}
