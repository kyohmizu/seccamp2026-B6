# Policy-as-Code: Binary Authorization ポリシーとカスタムアテスターを Terraform で宣言的に管理する。
# terraform plan で差分をレビュー → apply。手動 import を排し、変更履歴とピアレビューを担保する。

variable "project_id" { type = string }

# セキュリティレビュー用アテスターの公開鍵（PEM）。事前に署名鍵（KMS/PKIX 等）を生成して渡す。
variable "security_review_public_key_pem" {
  type        = string
  description = "security-review アテスターの検証用公開鍵（PKIX PEM）。"
}

# 2つ目のアテスター（セキュリティレビュー）。
# ※ 1つ目の built-by-cloud-build は Cloud Build が自動作成するため Terraform では管理しない。
resource "google_container_analysis_note" "security_review" {
  project = var.project_id
  name    = "security-review-note"
  attestation_authority {
    hint { human_readable_name = "Security review attestor" }
  }
}

resource "google_binary_authorization_attestor" "security_review" {
  project = var.project_id
  name    = "security-review"
  attestation_authority_note {
    note_reference = google_container_analysis_note.security_review.name
    public_keys {
      id = "security-review-key"
      pkix_public_key {
        public_key_pem      = var.security_review_public_key_pem
        signature_algorithm = "ECDSA_P256_SHA256"
      }
    }
  }
}

# デプロイ時検証ポリシー本体（プロジェクト単位のシングルトン）。
resource "google_binary_authorization_policy" "policy" {
  project = var.project_id

  default_admission_rule {
    evaluation_mode = "REQUIRE_ATTESTATION"
    # 段階導入: まず DRYRUN_AUDIT_LOG_ONLY で影響を確認し、問題なければ
    # ENFORCED_BLOCK_AND_AUDIT_LOG に変更して apply する。
    enforcement_mode = "DRYRUN_AUDIT_LOG_ONLY"

    # 複数アテスターの必須化（AND 条件）。built-by-cloud-build は自動作成のため名前で参照する。
    # security-review は .name（plan 時に既知）を組み込んで参照する。これで attestor への依存を保ちつつ、
    # terraform plan 上に両アテスターが差分として表示される（.id は apply まで unknown で plan に出ない）。
    require_attestations_by = [
      "projects/${var.project_id}/attestors/built-by-cloud-build",
      "projects/${var.project_id}/attestors/${google_binary_authorization_attestor.security_review.name}",
    ]
  }

  global_policy_evaluation_mode = "ENABLE"
}
