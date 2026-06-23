variable "permission_set_name" {
  description = "Permission Set 名（既存と衝突しない名前を推奨）"
  type        = string
  default     = "ClaudeInvestigator"
}

variable "description" {
  description = "Permission Set の説明（AWS SSO API は ASCII / Latin-1 のみ受け付ける）"
  type        = string
  default     = "Read-only investigation permissions for Claude Code (SSM Run Command + AWS environment read-only)."

  validation {
    condition     = can(regex("^[\\x20-\\x7E]+$", var.description))
    error_message = "description は ASCII 印字可能文字のみで記述してください（AWS SSO API は非 ASCII を拒否します）。"
  }
}

variable "session_duration" {
  description = "セッション期間（ISO 8601 duration）"
  type        = string
  default     = "PT8H"
}

variable "include_ssm" {
  description = "claude-investigate-* SSM Document の実行権限を含めるか"
  type        = bool
  default     = true
}

variable "include_athena" {
  description = "Athena 実行権限を含めるか（CloudFront ログ解析等）"
  type        = bool
  default     = false
}

variable "athena_regions" {
  description = <<-EOT
    Athena 実行・結果バケット作成を許可するリージョンのリスト。
    inline policy の aws:RequestedRegion 条件に使われ、ここに無いリージョンでは
    Athena 実行も結果バケット作成もできない。
    通常は呼び出し側で concat([primary_region], document_regions) を渡す。
    include_athena = true のとき、空にしないこと（空だと全リージョンで拒否になる）。

    注意: 結果バケット作成（s3:CreateBucket）の制限には s3:LocationConstraint を使うため、
    us-east-1 は LocationConstraint が空になり一致しない。us-east-1 で結果バケットを作る運用が
    必要な場合はバケットを事前作成するか、ポリシーに Null 条件を追加すること。
  EOT
  type        = list(string)
  default     = []
}

variable "athena_results_bucket_prefix" {
  description = <<-EOT
    Athena クエリ結果用バケットの名前プレフィックス。
    調査ロールはこのプレフィックスで始まる名前のバケットのみ作成・利用できる
    （既存の任意バケットは使わせない）。
    実際のバケット名規約は <prefix>-<アカウントID>-<リージョン>。
  EOT
  type        = string
  default     = "ssm-fleet-athena-results"
}

variable "athena_workgroup_name" {
  description = <<-EOT
    Athena 調査用 WorkGroup 名。調査ロールはこの名前の WorkGroup のみ作成できる
    （スキャン量上限などのコスト制御設定を持つ専用 WorkGroup）。
    primary WorkGroup は使わせない。
  EOT
  type        = string
  default     = "ssm-fleet-investigator"
}

variable "include_cloudwatch" {
  description = "CloudWatch メトリクス・ログ読み取り権限を含めるか"
  type        = bool
  default     = false
}

variable "attach_aws_readonly" {
  description = <<-EOT
    AWS managed policy ReadOnlyAccess を追加でアタッチするか。
    BREAKING CHANGE: デフォルトを false に変更。既存環境で明示的に true を指定していない場合、
    terraform apply で ReadOnlyAccess が削除される。既存利用者は tfvars に attach_aws_readonly = true を追加すること。
  EOT
  type        = bool
  default     = false
}

variable "target_account_ids" {
  description = "この permission set を割り当てる対象アカウント ID 一覧"
  type        = list(string)
  default     = []
}

variable "principal_id" {
  description = "割り当て対象のプリンシパル ID（IdentityStore のグループ or ユーザー ID）"
  type        = string
  default     = ""
}

variable "principal_type" {
  description = "プリンシパルタイプ（GROUP または USER）"
  type        = string
  default     = "GROUP"

  validation {
    condition     = contains(["GROUP", "USER"], var.principal_type)
    error_message = "principal_type は GROUP か USER のいずれかである必要があります。"
  }
}

variable "tags" {
  description = "追加タグ"
  type        = map(string)
  default     = {}
}
