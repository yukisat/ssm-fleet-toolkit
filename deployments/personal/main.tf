terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # 専用 state backend を委任管理アカウントに用意
  backend "s3" {
    bucket         = "366112400581-ssm-fleet-tf-state"
    key            = "ssm-fleet/personal/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "ssm-fleet-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region  = var.primary_region
  profile = var.aws_profile
}

# Organizations の全アカウントを取得
data "aws_organizations_organization" "this" {}

locals {
  target_account_ids = [
    for a in data.aws_organizations_organization.this.accounts : a.id
    if a.status == "ACTIVE"
  ]
}

# SSO Permission Set（オペレータ用）
module "permission_set" {
  source = "../../modules/sso-permission-set"

  permission_set_name = var.permission_set_name
  include_ssm         = var.enable_ssm_investigation
  include_athena      = var.enable_athena_investigation
  include_cloudwatch  = var.enable_cloudwatch_investigation
  attach_aws_readonly = true

  target_account_ids = local.target_account_ids
  principal_id       = var.investigator_group_id
  principal_type     = "GROUP"
}

# SSM Document の自動列挙
# documents/readonly/claude-investigate/<category>/<name>/document.yaml を全て登録する
locals {
  documents_root = "${path.module}/../../documents/readonly/claude-investigate"

  document_files = fileset(local.documents_root, "*/*/document.yaml")
  # 例: ["os/disk-usage/document.yaml", "nginx/access-log/document.yaml", ...]

  documents = {
    for p in local.document_files :
    replace(dirname(p), "/", "-") => {
      path     = "${local.documents_root}/${p}"
      category = split("/", p)[0]
    }
  }
  # 例: { "os-disk-usage" = { path = "...", category = "os" }, ... }
}

# SSM Document の登録 + Organizations 全アカウント共有
module "doc" {
  source   = "../../modules/ssm-document"
  for_each = local.documents

  document_name      = "claude-investigate-${each.key}"
  document_path      = each.value.path
  category           = each.value.category
  shared_account_ids = local.target_account_ids
}
