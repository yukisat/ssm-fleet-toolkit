terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # backend "s3" {
  #   bucket         = "<your-account>-ssm-fleet-tf-state"
  #   key            = "ssm-fleet/single-account/terraform.tfstate"
  #   region         = "ap-northeast-1"
  #   dynamodb_table = "ssm-fleet-tf-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# SSM Document の登録（共有なし、自アカウント内のみ）
module "doc_disk_usage" {
  source = "../../../modules/ssm-document"

  document_name = "claude-investigate-os-disk-usage"
  document_path = "../../../documents/readonly/claude-investigate/os/disk-usage/document.yaml"
  category      = "os"
}

# 単一アカウントでは SSO Permission Set ではなく IAM ロールに直接アタッチを推奨
# 詳細は README.md 参照
