terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # 専用 state backend を委任管理アカウントに用意
  # backend "s3" {
  #   bucket         = "<delegated-admin-account>-ssm-fleet-tf-state"
  #   key            = "ssm-fleet/<your-org>/terraform.tfstate"
  #   region         = "ap-northeast-1"
  #   dynamodb_table = "ssm-fleet-tf-lock"
  #   encrypt        = true
  # }
}

locals {
  # aws_profile が空文字のとき null にして標準クレデンシャルチェーン（env vars 等）を使う
  aws_profile = var.aws_profile != "" ? var.aws_profile : null
}

provider "aws" {
  region  = var.primary_region
  profile = local.aws_profile
}

# SSO / IAM Identity Center 操作用 provider。
# Identity Center は primary_region とは別リージョンに存在することが多いため
# （例: us-west-2）、permission_set モジュールはこの provider で操作する。
# sso_region に Identity Center のホームリージョンを指定すること。
provider "aws" {
  alias   = "sso"
  region  = var.sso_region
  profile = local.aws_profile
}

# ---------------------------------------------------------------------------
# セカンダリリージョン用 provider（SSM Document を複数リージョンへ展開する場合に使う）
#
# SSM Document はリージョンごとに登録が必要なため、primary_region 以外で調査対象
# インスタンスを運用している場合は、そのリージョンにも同じ Document を登録する。
# 展開先は var.document_regions（リスト）で opt-in 指定する。
#
# 新しいリージョンを追加したいとき:
#   1) ここに provider ブロックを 1 つ追加（alias を付ける）
#   2) variables.tf の document_regions の validation 許可リストに追加
#   3) 末尾の「セカンダリリージョンへの Document 登録」に module ブロックを 1 つ追加
# Terraform は provider をリストから動的生成できないため、この 3 点はリージョンごとに
# 明示的に書く必要がある。
# ---------------------------------------------------------------------------
provider "aws" {
  alias   = "us_west_2"
  region  = "us-west-2"
  profile = local.aws_profile
}

provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = local.aws_profile
}

provider "aws" {
  alias   = "ap_southeast_1"
  region  = "ap-southeast-1"
  profile = local.aws_profile
}

provider "aws" {
  alias   = "ap_northeast_3"
  region  = "ap-northeast-3"
  profile = local.aws_profile
}

provider "aws" {
  alias   = "eu_west_1"
  region  = "eu-west-1"
  profile = local.aws_profile
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
  providers = {
    aws = aws.sso
  }

  permission_set_name = var.permission_set_name
  include_ssm         = var.enable_ssm_investigation
  include_athena      = var.enable_athena_investigation
  include_cloudwatch  = var.enable_cloudwatch_investigation
  attach_aws_readonly = var.attach_aws_readonly

  # Athena の実行・結果バケット作成を許可するリージョン = primary + セカンダリ展開先
  athena_regions = concat([var.primary_region], var.document_regions)

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

# SSM Document の登録 + Organizations 全アカウント共有（primary_region）
module "doc" {
  source   = "../../modules/ssm-document"
  for_each = local.documents

  document_name      = "claude-investigate-${each.key}"
  document_path      = each.value.path
  category           = each.value.category
  shared_account_ids = local.target_account_ids
}

# ---------------------------------------------------------------------------
# セカンダリリージョンへの Document 登録
#
# var.document_regions に含まれるリージョンにのみ登録する（含まれない場合は空 map
# で for_each が回らないため、リソースは作られない）。primary の module.doc とは
# 別アドレスなので、既存の primary 側 Document には一切影響しない。
# ---------------------------------------------------------------------------
module "doc_us_west_2" {
  source   = "../../modules/ssm-document"
  for_each = contains(var.document_regions, "us-west-2") ? local.documents : {}
  providers = {
    aws = aws.us_west_2
  }

  document_name      = "claude-investigate-${each.key}"
  document_path      = each.value.path
  category           = each.value.category
  shared_account_ids = local.target_account_ids
}

module "doc_us_east_1" {
  source   = "../../modules/ssm-document"
  for_each = contains(var.document_regions, "us-east-1") ? local.documents : {}
  providers = {
    aws = aws.us_east_1
  }

  document_name      = "claude-investigate-${each.key}"
  document_path      = each.value.path
  category           = each.value.category
  shared_account_ids = local.target_account_ids
}

module "doc_ap_southeast_1" {
  source   = "../../modules/ssm-document"
  for_each = contains(var.document_regions, "ap-southeast-1") ? local.documents : {}
  providers = {
    aws = aws.ap_southeast_1
  }

  document_name      = "claude-investigate-${each.key}"
  document_path      = each.value.path
  category           = each.value.category
  shared_account_ids = local.target_account_ids
}

module "doc_ap_northeast_3" {
  source   = "../../modules/ssm-document"
  for_each = contains(var.document_regions, "ap-northeast-3") ? local.documents : {}
  providers = {
    aws = aws.ap_northeast_3
  }

  document_name      = "claude-investigate-${each.key}"
  document_path      = each.value.path
  category           = each.value.category
  shared_account_ids = local.target_account_ids
}

module "doc_eu_west_1" {
  source   = "../../modules/ssm-document"
  for_each = contains(var.document_regions, "eu-west-1") ? local.documents : {}
  providers = {
    aws = aws.eu_west_1
  }

  document_name      = "claude-investigate-${each.key}"
  document_path      = each.value.path
  category           = each.value.category
  shared_account_ids = local.target_account_ids
}
