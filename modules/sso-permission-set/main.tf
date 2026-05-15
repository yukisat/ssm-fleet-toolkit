terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_ssoadmin_instances" "this" {}

locals {
  instance_arn      = data.aws_ssoadmin_instances.this.arns[0]
  identity_store_id = data.aws_ssoadmin_instances.this.identity_store_ids[0]

  # 機能フラグごとに inline policy JSON を合成
  policy_files = compact([
    var.include_ssm ? "${path.module}/policies/claude-investigator-ssm.json" : "",
    var.include_athena ? "${path.module}/policies/claude-investigator-athena.json" : "",
    var.include_cloudwatch ? "${path.module}/policies/claude-investigator-cloudwatch.json" : "",
  ])

  combined_statements = flatten([
    for f in local.policy_files : jsondecode(file(f)).Statement
  ])

  combined_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.combined_statements
  })
}

resource "aws_ssoadmin_permission_set" "this" {
  name             = var.permission_set_name
  description      = var.description
  instance_arn     = local.instance_arn
  session_duration = var.session_duration

  tags = merge(
    {
      "ssm-fleet:managed-by" = "ssm-fleet-toolkit"
    },
    var.tags,
  )
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly" {
  count = var.attach_aws_readonly ? 1 : 0

  instance_arn       = local.instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.this.arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  count = length(local.policy_files) > 0 ? 1 : 0

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this.arn
  inline_policy      = local.combined_policy
}

# 対象アカウントへの割り当て（principal_id / type は呼び出し側から指定）
resource "aws_ssoadmin_account_assignment" "this" {
  for_each = toset(var.target_account_ids)

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this.arn

  principal_id   = var.principal_id
  principal_type = var.principal_type

  target_id   = each.value
  target_type = "AWS_ACCOUNT"
}
