variable "project_id" {
  type        = string
  description = "この環境のリソースを作る GCP プロジェクト。別プロジェクト方式なら env ごとに変える/共有プロジェクト方式なら全 env 同じ値。"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "name_prefix" {
  type        = string
  description = "サービス/SA/リポジトリ名の接頭辞。共有プロジェクト方式では env ごとに一意にする（分離の要）。"
}

variable "repo_id" {
  type        = string
  default     = null
  description = "Artifact Registry リポジトリ名。未指定なら name_prefix を流用。"
}

variable "bootstrap_image" {
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
  description = "Cloud Run 初回作成用のプレースホルダ。実イメージはパイプラインが更新（image は ignore_changes）。"
}

variable "members" {
  type        = list(string)
  default     = []
  description = "frontend を proxy で閲覧できるユーザ/グループ（例: user:you@example.com）。利用者本人をここに入れる。"
}
