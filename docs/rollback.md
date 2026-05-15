# ロールバック手順

セットアップが失敗した場合、または導入を取りやめたい場合の手順。

## 推奨ルート（Terraform で管理されている場合）

各 deployment ディレクトリで `terraform destroy`:

```bash
cd deployments/<your-org>/
terraform destroy
```

確認プロンプトで内容を確認し、`yes` で実行。
すべての作成リソースが Terraform 管理下のため、これで完全に元の状態に戻ります。

## 手動ルート（state を失った場合等）

```bash
./bootstrap/99-rollback.sh
```

このスクリプトは以下を順に削除確認します:

1. SSM Document（`claude-investigate-*` のみ）
2. DynamoDB テーブル（`ssm-fleet-tf-lock*` のみ）
3. S3 バケット（`*-ssm-fleet-tf-state*` のみ）

各削除は対話的に確認されます（`--yes` で自動承諾も可能だが非推奨）。

## 削除されないもの

- 子アカウントに配布された IAM ロール（StackSet 経由のため、StackSet 削除が必要）
- CloudFormation StackSet 自体（`terraform destroy` または手動削除）
- SSO Permission Set（`terraform destroy` または手動削除）
- AWS Organizations の trusted access（無効化すると他ツールに影響する可能性があるため自動削除しない）

## 段階的なロールバック

機能ごとに段階的に戻すことも可能:

### Document だけ削除（権限は残す）

```bash
cd deployments/<your-org>/
terraform destroy -target=module.ssm_documents
```

### Permission Set だけ削除（Document は残す）

```bash
terraform destroy -target=module.permission_set
```

## 既存環境への影響

すべての操作は `ssm-fleet-*` / `claude-investigate-*` プレフィックスのリソースに限定されます。
**プレフィックスが一致しない既存リソースには一切触れません。**

## 確認方法

ロールバック後、以下のコマンドで残存リソースを確認:

```bash
# SSM Document
aws ssm list-documents --filters Key=Name,Values=claude-investigate

# IAM Role
aws iam list-roles --query 'Roles[?starts_with(RoleName, `ssm-fleet-`)].RoleName'

# Permission Set
aws sso-admin list-permission-sets --instance-arn <arn>
```

すべて空または対象なしであればロールバック完了です。

## トラブルシューティング

| 現象 | 対応 |
|---|---|
| terraform destroy が S3 バケット削除でエラー | バケット内のオブジェクトを先に削除（`aws s3 rb s3://<bucket> --force`） |
| StackSet 削除がエラー | 子アカウントの StackInstances を先に削除する必要あり |
| Permission Set 削除がエラー | 割り当て（assignment）を先に削除する必要あり。terraform 経由なら自動 |
| trusted access を無効化したい | `aws organizations disable-aws-service-access --service-principal member.org.stacksets.cloudformation.amazonaws.com`（他ツール影響に注意） |
