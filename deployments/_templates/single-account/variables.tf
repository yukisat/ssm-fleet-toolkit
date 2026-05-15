variable "aws_profile" {
  description = "AWS CLI profile 名"
  type        = string
  default     = "default"
}

variable "region" {
  description = "デプロイ先リージョン"
  type        = string
  default     = "ap-northeast-1"
}
