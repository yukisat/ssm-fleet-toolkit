# Terraform Module: iam-stackset

子アカウントに `ssm-fleet-*` プレフィックスの IAM ロールを配布するための CloudFormation StackSet モジュール。

## 状態

**未実装（スタブのみ）**。

設計案:

- `aws_cloudformation_stack_set` で service-managed StackSet を作成
- `aws_cloudformation_stack_set_instance` で Organizations 全アクティブアカウントに展開
- 配布する CloudFormation テンプレートは inline で持つか、`templates/` 配下に置く
- ロール名は `ssm-fleet-investigate-role` 固定（変更可能にする）

実装は次のマイルストーンで対応。
