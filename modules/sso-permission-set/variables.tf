variable "permission_set_name" {
  description = "Permission Set 名（既存と衝突しない名前を推奨）"
  type        = string
  default     = "ClaudeInvestigator"
}

variable "description" {
  description = "Permission Set の説明"
  type        = string
  default     = "Claude Code による read-only な調査用権限。SSM Document 実行と AWS 環境調査をカバー。"
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

variable "include_cloudwatch" {
  description = "CloudWatch メトリクス・ログ読み取り権限を含めるか"
  type        = bool
  default     = false
}

variable "attach_aws_readonly" {
  description = "AWS managed policy ReadOnlyAccess を追加でアタッチするか"
  type        = bool
  default     = true
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
