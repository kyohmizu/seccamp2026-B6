output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "name_prefix" {
  value = var.name_prefix
}

output "backend_name" {
  value = google_cloud_run_v2_service.backend.name
}

output "frontend_name" {
  value = google_cloud_run_v2_service.frontend.name
}

output "backend_url" {
  value = google_cloud_run_v2_service.backend.uri
}

output "frontend_url" {
  value = google_cloud_run_v2_service.frontend.uri
}

output "artifact_registry" {
  value = "${local.ar_host}/${var.project_id}/${local.repo_id}"
}

output "repo_id" {
  value = local.repo_id
}

output "backend_sa" {
  value = google_service_account.backend.email
}

output "frontend_sa" {
  value = google_service_account.frontend.email
}
