# Deployment Template: single-account

単一 AWS アカウント環境用のテンプレート。Organizations や SSO は不要。

## 使い方

```bash
cp -r deployments/_templates/single-account deployments/<your-name>
cd deployments/<your-name>
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集（profile 名・region）
terraform init
terraform plan
terraform apply
```

## 提供されるもの

- 自アカウント内に `claude-investigate-*` Document が登録される
- 他アカウントへの共有はしない

## 権限

単一アカウントでは SSO Permission Set ではなく、既存の IAM ユーザー or IAM ロールに
オペレータポリシー（`modules/sso-permission-set/policies/claude-investigator-ssm.json`）を
直接アタッチするのが簡単です。例:

```bash
aws iam put-user-policy \
  --user-name <your-user> \
  --policy-name ClaudeInvestigator \
  --policy-document file://../../../modules/sso-permission-set/policies/claude-investigator-ssm.json
```

## バックエンド

シングルアカウントなので Terraform backend は任意。
ローカル state でも可、本格運用なら S3 backend を有効化（main.tf 内のコメント解除）。
