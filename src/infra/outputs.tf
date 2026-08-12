# 環境ごとの主要な情報（利用者への配布・プロビジョニングスクリプトが利用）。
output "environments" {
  value = {
    for k, m in module.environment : k => {
      project_id        = m.project_id
      region            = m.region
      name_prefix       = m.name_prefix
      backend_name      = m.backend_name
      frontend_name     = m.frontend_name
      backend_url       = m.backend_url
      frontend_url      = m.frontend_url
      artifact_registry = m.artifact_registry
      repo_id           = m.repo_id
      backend_sa        = m.backend_sa
      frontend_sa       = m.frontend_sa
    }
  }
}
