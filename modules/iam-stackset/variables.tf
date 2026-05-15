variable "stackset_name" {
  description = "StackSet 名（ssm-fleet-* プレフィックス推奨）"
  type        = string
  default     = "ssm-fleet-investigate-role"

  validation {
    condition     = can(regex("^ssm-fleet-", var.stackset_name))
    error_message = "stackset_name は 'ssm-fleet-' プレフィックスで始まる必要があります。"
  }
}

variable "role_name" {
  description = "子アカウントに作成される IAM ロール名"
  type        = string
  default     = "ssm-fleet-investigate-role"

  validation {
    condition     = can(regex("^ssm-fleet-", var.role_name))
    error_message = "role_name は 'ssm-fleet-' プレフィックスで始まる必要があります。"
  }
}

variable "delegated_admin_account_id" {
  description = "ロールを引き受ける委任管理アカウント ID"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.delegated_admin_account_id))
    error_message = "AWS アカウント ID は 12 桁の数字である必要があります。"
  }
}

variable "deploy_to_entire_organization" {
  description = "Organizations 全体にデプロイするか（true なら organizational_unit_ids 必須）"
  type        = bool
  default     = false
}

variable "organizational_unit_ids" {
  description = "デプロイ対象の OU ID リスト（Root OU を含めると全アカウントが対象）"
  type        = list(string)
  default     = []
}

variable "target_account_ids" {
  description = "個別アカウントデプロイ用のアカウント ID リスト"
  type        = list(string)
  default     = []
}

variable "region" {
  description = "デプロイ対象リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "failure_tolerance_count" {
  description = "許容する失敗アカウント数"
  type        = number
  default     = 2
}

variable "max_concurrent_count" {
  description = "並行実行するアカウント数の上限"
  type        = number
  default     = 5
}

variable "tags" {
  description = "追加タグ"
  type        = map(string)
  default     = {}
}
