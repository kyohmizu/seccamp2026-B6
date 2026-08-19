variable "google_project" {
  type        = string
  description = "プロバイダの課金/クォータ用プロジェクト（API 呼び出しの請求先）。共有プロジェクト方式ならその共有プロジェクト、別プロジェクト方式なら操作元として使用する任意の1プロジェクトでよい。"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "bootstrap_image" {
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
  description = "Cloud Run 初回作成用のプレースホルダ。実イメージはパイプラインが更新（image は ignore_changes）。"
}

variable "app_count" {
  type        = number
  default     = 0
  description = "GitHub 連携付きの演習環境を生成する数。>0 なら app-01.. を自動生成し、リポジトリ seccamp2026-B6-app-NN への push/PR/deploy トリガーまで作る。個別設定が必要な場合は 0 にして environments を明示する。"
}

variable "github_owner" {
  type        = string
  default     = null
  description = "演習用リポジトリの GitHub owner（個人アカウント名 or 組織名）。app_count > 0 のとき必須。"
}

variable "connection_name" {
  type        = string
  default     = "flowpay-github"
  description = "Cloud Build の host connection 名（gcloud で作成・OAuth 認可済みのもの）。app_count で作る全 env が共通で使う。"
}

variable "npm_registry" {
  type        = string
  default     = ""
  description = "演習用 npm レジストリ（Verdaccio）URL。トリガーの _NPM_REGISTRY として注入し frontend の expense-format を解決する。環境固有・IP を含むため tfvars で指定（コミットしない）。"
}

variable "app_build_sa" {
  type        = string
  default     = null
  description = "app_count で作る push/PR トリガーが使うビルド実行 SA（フルパス projects/<p>/serviceAccounts/<email>）。リージョナル（2nd-gen）トリガーは SA 指定が必須。演習04 前の状態としては既定の Compute SA（over-privileged）を指定する。"
}

# 環境ごとに個別設定が必要な場合の明示指定（別プロジェクト・別リポジトリ・個別アクセス等）。
# 通常は app_count を使用し、こちらは空でよい。1エントリ＝1環境。
variable "environments" {
  type = map(object({
    project_id  = string
    name_prefix = optional(string) # 未指定ならマップのキーを流用
    repo_id     = optional(string)
    members     = optional(list(string), []) # frontend を閲覧できる人（演習の実行者など）

    # --- source-trigger（GitHub＋Cloud Build トリガー）。github_repo を入れた env だけ作られる ---
    github_owner             = optional(string)
    github_repo              = optional(string)
    connection_name          = optional(string)          # gcloud で作成済みの host connection 名
    build_sa                 = optional(string)          # トリガーのビルド実行SA（最小権限SA推奨、フルリソースパス）
    cloudbuild_config        = optional(string)          # トリガーが実行する cloudbuild 定義のパス。未指定ならモジュール既定。実行者ごとの別リポジトリなら "cloudbuild.yaml"
    pr_cloudbuild_config     = optional(string)          # PRチェック用 cloudbuild 定義のパス。未指定ならモジュール既定。実行者ごとの別リポジトリなら "cloudbuild.pr.yaml"
    deploy_cloudbuild_config = optional(string)          # デプロイ用 cloudbuild 定義のパス。未指定ならモジュール既定。実行者ごとの別リポジトリなら "cloudbuild.deploy.yaml"
    enable_pr_check          = optional(bool, true)      # pull_request でPRチェックを実行するか
    enable_deploy_trigger    = optional(bool, true)      # イメージ push（Pub/Sub）でデプロイtrigger を実行するか
    substitutions            = optional(map(string), {}) # トリガーに渡す substitution（例: { _NPM_REGISTRY = "http://<IP>:4873/" }）。環境固有値は tfvars で。
  }))
  default = {}
}
