output "stackset_name" {
  description = "作成された StackSet の名前"
  value       = aws_cloudformation_stack_set.investigate_role.name
}

output "stackset_id" {
  description = "StackSet の ID"
  value       = aws_cloudformation_stack_set.investigate_role.stack_set_id
}

output "role_name" {
  description = "子アカウントに配布される IAM ロール名"
  value       = var.role_name
}
