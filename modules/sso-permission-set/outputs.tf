output "permission_set_arn" {
  description = "作成された Permission Set の ARN"
  value       = aws_ssoadmin_permission_set.this.arn
}

output "permission_set_name" {
  description = "作成された Permission Set の名前"
  value       = aws_ssoadmin_permission_set.this.name
}

output "instance_arn" {
  description = "SSO インスタンス ARN（参照用）"
  value       = local.instance_arn
}

output "assigned_account_ids" {
  description = "割り当て対象アカウント ID 一覧"
  value       = var.target_account_ids
}
