variable "aws_profile" {
  description = <<-EOT
    委任管理アカウントの AWS CLI profile 名。
    空文字 "" にすると profile を指定せず、環境変数（AWS_ACCESS_KEY_ID 等の
    SSO 一時キー）など標準のクレデンシャルチェーンを使う。
  EOT
  type        = string
  default     = ""
}

variable "primary_region" {
  description = "primary リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "sso_region" {
  description = <<-EOT
    IAM Identity Center（SSO）のホームリージョン。permission_set モジュールはこの
    リージョンで SSO を操作する。primary_region とは別になることが多い
    （Identity Center は組織で1リージョンにのみ存在する）。
  EOT
  type        = string
  default     = "us-west-2"
}

variable "permission_set_name" {
  description = "作成する Permission Set 名"
  type        = string
  default     = "ClaudeInvestigator"
}

variable "document_regions" {
  description = <<-EOT
    SSM Document を primary_region に加えて展開するセカンダリリージョンのリスト。
    調査対象インスタンスが primary 以外のリージョンにもある場合に指定する。
    例: ["us-west-2"]

    SSM Document はリージョンごとに登録が必要なため、ここに挙げたリージョンへ
    primary と同じ claude-investigate-* Document を登録・共有する。
    primary_region はここに含めなくてよい（常に登録される）。

    指定できるのは main.tf に provider が定義済みのリージョンのみ。
    新しいリージョンを足す場合は main.tf に provider と module ブロックを追加すること。

    注意: リストからリージョンを外して apply すると、そのリージョンの
    claude-investigate-* Document はすべて削除（destroy）される。
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for r in var.document_regions :
      contains(["us-west-2", "us-east-1", "ap-southeast-1", "ap-northeast-3", "eu-west-1"], r)
    ])
    error_message = "document_regions に指定できるのは main.tf に provider 定義済みのリージョンのみです（us-west-2 / us-east-1 / ap-southeast-1 / ap-northeast-3 / eu-west-1）。他のリージョンを使う場合は main.tf に provider と module ブロックを追加してください。"
  }
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
  description = <<-EOT
    Athena 実行権限を Permission Set に含めるか。
    true にすると ClaudeInvestigator Permission Set に Athena/Glue/S3 read 等の
    inline policy が追加される。**playbook の自動登録は伴わない**：
    playbooks/readonly/athena/ 配下は catalog から参照される手順書のみで、
    Terraform で何かをデプロイするものではない。
  EOT
  type        = bool
  default     = false
}

variable "attach_aws_readonly" {
  description = <<-EOT
    AWS managed policy ReadOnlyAccess を Permission Set に追加するか（opt-in）。
    BREAKING CHANGE: v0.x から移行した場合は明示的に true を指定すること。
  EOT
  type        = bool
  default     = false
}

variable "enable_cloudwatch_investigation" {
  description = <<-EOT
    CloudWatch 読み取り権限を Permission Set に含めるか。
    true にすると ClaudeInvestigator Permission Set に cloudwatch:GetMetricData 等の
    inline policy が追加される。**playbook の自動登録は伴わない**：
    playbooks/readonly/cloudwatch/ 配下は catalog から参照される手順書のみで、
    Terraform で何かをデプロイするものではない。
  EOT
  type        = bool
  default     = false
}
