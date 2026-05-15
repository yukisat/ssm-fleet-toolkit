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

  tags = merge(
    {
      "ssm-fleet:managed-by" = "ssm-fleet-toolkit"
      "ssm-fleet:category"   = var.category
      "ssm-fleet:safety"     = var.safety
    },
    var.tags,
  )

  dynamic "permissions" {
    for_each = length(var.shared_account_ids) > 0 ? [1] : []
    content {
      type        = "Share"
      account_ids = join(",", var.shared_account_ids)
    }
  }
}
