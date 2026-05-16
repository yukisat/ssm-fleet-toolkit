# Deployment Template

AWS Organizations 配下の複数アカウントに Document を一括展開する唯一のテンプレート。SSO 統合前提。

## 前提

- AWS Organizations が all-features モード
- StackSets trusted access が有効
- AWS SSO が有効化済み、IdentityStore グループが存在
- 委任管理アカウントが決定済み

`bootstrap/00-check-prerequisites.sh` で確認可能。

## 使い方

```bash
cp -r deployments/_template deployments/<your-org>
cd deployments/<your-org>
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集
terraform init
terraform plan   # ★ 0 to change, 0 to destroy を確認
terraform apply
```

## 提供されるもの

- 委任管理アカウントに `claude-investigate-*` Document を登録
- Organizations 全アクティブアカウントに Document を共有
- SSO Permission Set `ClaudeInvestigator` を作成し、指定グループに割り当て
- 機能ごとの opt-in（SSM のみ / Athena / CloudWatch）

## 設定値の取得方法

### investigator_group_id

```bash
aws identitystore list-groups \
  --identity-store-id $(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text) \
  --query 'Groups[?DisplayName==`Investigators`].GroupId' --output text
```

事前にグループを作成しておくこと（このツールはグループ管理はしない）。

## 既存環境との共存

`docs/coexistence.md` を参照。
このテンプレートは `claude-investigate-*` Document と指定名 Permission Set のみを作成し、既存リソースに触れない。
