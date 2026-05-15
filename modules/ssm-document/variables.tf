variable "document_name" {
  description = "SSM Document 名。claude-investigate-* プレフィックス推奨"
  type        = string

  validation {
    condition     = can(regex("^claude-investigate-", var.document_name))
    error_message = "document_name は 'claude-investigate-' プレフィックスで始まる必要があります。"
  }
}

variable "document_path" {
  description = "Document 本体ファイルへのパス（YAML or JSON）"
  type        = string
}

variable "document_format" {
  description = "Document フォーマット（YAML / JSON）"
  type        = string
  default     = "YAML"

  validation {
    condition     = contains(["YAML", "JSON"], var.document_format)
    error_message = "document_format は YAML か JSON のいずれかである必要があります。"
  }
}

variable "shared_account_ids" {
  description = <<-EOT
    この Document を共有する AWS アカウント ID のリスト。
    空配列の場合は共有なし（自アカウント内でのみ利用可能）。
    Organizations 配下の全アカウントを指定したい場合は呼び出し側で
    aws_organizations_organization データソースから生成すること。
  EOT
  type        = list(string)
  default     = []
}

variable "category" {
  description = "Document のカテゴリ（os / nginx / php / wordpress 等）。タグとして付与"
  type        = string
}

variable "safety" {
  description = "Document の安全レベル（readonly のみ許可）"
  type        = string
  default     = "readonly"

  validation {
    condition     = var.safety == "readonly"
    error_message = "現在の本モジュールは safety=readonly のみサポートします。"
  }
}

variable "tags" {
  description = "追加タグ"
  type        = map(string)
  default     = {}
}
