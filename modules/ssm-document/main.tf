terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_ssm_document" "this" {
  name            = var.document_name
  document_type   = "Command"
  document_format = var.document_format

  content = file(var.document_path)

  # permissions は map 属性。空配列の場合は null で属性を作らない
  permissions = length(var.shared_account_ids) > 0 ? {
    type        = "Share"
    account_ids = join(",", var.shared_account_ids)
  } : null

  tags = merge(
    {
      "ssm-fleet:managed-by" = "ssm-fleet-toolkit"
      "ssm-fleet:category"   = var.category
      "ssm-fleet:safety"     = var.safety
    },
    var.tags,
  )
}
