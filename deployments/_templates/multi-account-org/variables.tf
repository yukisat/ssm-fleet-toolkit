variable "aws_profile" {
  description = "委任管理アカウントの AWS CLI profile"
  type        = string
}

variable "primary_region" {
  description = "primary リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "permission_set_name" {
  description = "作成する Permission Set 名"
  type        = string
  default     = "ClaudeInvestigator"
}

variable "investigator_group_id" {
  description = "Permission Set を割り当てる IdentityStore グループ ID"
  type        = string
}

variable "enable_ssm_investigation" {
  description = "SSM Document 実行権限を含めるか"
  type        = bool
  default     = true
}

variable "enable_athena_investigation" {
  description = "Athena 実行権限を含めるか"
  type        = bool
  default     = false
}

variable "enable_cloudwatch_investigation" {
  description = "CloudWatch 読み取り権限を含めるか"
  type        = bool
  default     = false
}
