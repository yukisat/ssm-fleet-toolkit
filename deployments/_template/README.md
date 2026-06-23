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

### document_regions（複数リージョン展開）

SSM Document はリージョンごとに登録が必要。調査対象インスタンスが `primary_region` 以外の
リージョンにもある場合は `document_regions` に追加リージョンを指定する。

```hcl
document_regions = ["us-west-2"]
```

- `primary_region` は常に登録されるのでここには含めない。
- 指定したリージョンへ primary と同じ `claude-investigate-*` Document を登録・共有する。
- primary 側の Document（`module.doc`）とは別アドレスなので既存リージョンには影響しない。
- 同梱済みリージョン: us-west-2 / us-east-1 / ap-southeast-1 / ap-northeast-3 / eu-west-1。
  これ以外を使う場合は Terraform の制約上、main.tf に provider と module ブロックを追加し、
  variables.tf の validation 許可リストにも足すこと（main.tf 冒頭のコメント参照）。
- **注意**: 一度展開したリージョンを `document_regions` から外して apply すると、そのリージョンの
  `claude-investigate-*` Document はすべて削除（destroy）される。減らす変更時は plan で確認すること。

## 既存環境との共存

`docs/coexistence.md` を参照。
このテンプレートは `claude-investigate-*` Document と指定名 Permission Set のみを作成し、既存リソースに触れない。
