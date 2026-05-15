# Terraform Module: iam-stackset

CloudFormation StackSet で子アカウントに `ssm-fleet-investigate-role` IAM ロールを配布するモジュール。

## 前提

- AWS Organizations が all-features モード
- StackSets trusted access が有効（`bootstrap/01-enable-stacksets-trusted.sh`）
- 委任管理アカウントから実行

## 使い方

### Organizations 全体に配布

```hcl
data "aws_organizations_organization" "this" {}

module "investigate_role_stackset" {
  source = "../../modules/iam-stackset"

  delegated_admin_account_id    = "YOUR_ACCOUNT_ID"
  deploy_to_entire_organization = true
  organizational_unit_ids       = [data.aws_organizations_organization.this.roots[0].id]
  region                        = "ap-northeast-1"
}
```

### 個別アカウント指定

```hcl
module "investigate_role_stackset" {
  source = "../../modules/iam-stackset"

  delegated_admin_account_id = "YOUR_ACCOUNT_ID"
  target_account_ids         = ["111111111111", "222222222222"]
  region                     = "ap-northeast-1"
}
```

## 配布される IAM ロール

各子アカウントに以下が作成される:

- ロール名: `ssm-fleet-investigate-role`（変更可）
- 信頼ポリシー: 委任管理アカウントの root
- 権限: `claude-investigate-*` Document 実行のみ（書き込みなし）

## マルチリージョン展開

このモジュールは 1 リージョンに 1 つの StackSet を作る設計。
複数リージョンに展開したい場合は provider alias で region 別に複数モジュールを呼び出すこと。

## 既存環境への影響

- StackSet 名 `ssm-fleet-*` プレフィックス強制（既存 StackSet と衝突しない）
- 子アカウントに作る IAM ロール名 `ssm-fleet-*` プレフィックス強制
- ロール削除は `terraform destroy` または StackSet を Delete することで子アカウントから自動削除される
