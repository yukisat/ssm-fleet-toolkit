# Terraform Module: sso-permission-set

AWS SSO permission set を作成し、調査用 inline policy を機能フラグで合成する汎用モジュール。

## 設計

- 機能ごとに inline policy JSON を分離（`policies/*.json`）
- `include_ssm`, `include_athena`, `include_cloudwatch` のフラグで必要な権限だけを合成
- AWS managed `ReadOnlyAccess` を任意でアタッチ
- 既存の SSO インスタンス・グループは `data` 経由で参照（管理しない）
- このモジュールが管理するのは指定の permission set のみ。他の permission set は一切触らない

## 使い方

### SSM のみ（最小構成）

```hcl
module "claude_investigator" {
  source = "../../modules/sso-permission-set"

  permission_set_name = "ClaudeInvestigator"
  include_ssm         = true
  include_athena      = false
  include_cloudwatch  = false
  attach_aws_readonly = true

  target_account_ids = ["022646323280"]
  principal_id       = data.aws_identitystore_group.investigators.group_id
  principal_type     = "GROUP"
}
```

### フル機能（SSM + Athena + CloudWatch）

```hcl
module "claude_investigator" {
  source = "../../modules/sso-permission-set"

  include_ssm        = true
  include_athena     = true
  include_cloudwatch = true

  target_account_ids = data.aws_organizations_organization.this.accounts[*].id
  principal_id       = data.aws_identitystore_group.investigators.group_id
}
```

## inline policy サイズ上限への配慮

SSO permission set の inline policy は 10KB 上限。
すべての機能を有効化しても 10KB 内に収まるよう設計しているが、将来カスタムポリシーを追加する場合は要確認。

## 機能追加の手順

1. `policies/claude-investigator-<feature>.json` を新規作成
2. `variables.tf` に `include_<feature>` を追加
3. `main.tf` の `policy_files` ローカルに条件分岐を追加

## 既存環境への影響

- このモジュールが管理するのは指定名の permission set 1 つのみ
- 既存の permission set には一切触らない（`data` source も使わない）
- 同名の permission set が既に存在する場合は `terraform import` または別名指定が必要
