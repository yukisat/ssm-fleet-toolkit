output "document_name" {
  description = "登録された SSM Document の名前"
  value       = aws_ssm_document.this.name
}

output "document_arn" {
  description = "登録された SSM Document の ARN"
  value       = aws_ssm_document.this.arn
}

output "shared_with_accounts" {
  description = "共有先アカウント ID のリスト"
  value       = var.shared_account_ids
}
