# Terraform Module: ssm-document

SSM Document を登録し、必要に応じて他 AWS アカウントへ共有する汎用モジュール。

## 使い方

### 単一アカウント（共有なし）

```hcl
module "disk_usage" {
  source = "../../modules/ssm-document"

  document_name = "claude-investigate-os-disk-usage"
  document_path = "../../documents/readonly/claude-investigate/os/disk-usage/document.yaml"
  category      = "os"
}
```

### Organizations 全アカウントに共有

```hcl
data "aws_organizations_organization" "this" {}

module "disk_usage" {
  source = "../../modules/ssm-document"

  document_name      = "claude-investigate-os-disk-usage"
  document_path      = "../../documents/readonly/claude-investigate/os/disk-usage/document.yaml"
  category           = "os"
  shared_account_ids = [for a in data.aws_organizations_organization.this.accounts : a.id]
}
```

### 手動指定の複数アカウントに共有

```hcl
module "disk_usage" {
  source = "../../modules/ssm-document"

  document_name      = "claude-investigate-os-disk-usage"
  document_path      = "../../documents/readonly/claude-investigate/os/disk-usage/document.yaml"
  category           = "os"
  shared_account_ids = ["111111111111", "222222222222"]
}
```

## 設計

- `shared_account_ids` が空配列なら `permissions` リソースを生成しない（単一アカウント運用と互換）
- `document_name` は `claude-investigate-` プレフィックス必須（validation あり）
- `safety` は `readonly` のみ許可（stateful Document をこのモジュールで登録できない安全策）
- タグで `ssm-fleet:managed-by`, `ssm-fleet:category`, `ssm-fleet:safety` を自動付与

## マルチリージョン展開

このモジュールは単一リージョンに登録する。複数リージョンに同じ Document を登録したい場合は、provider alias で対象リージョンごとにモジュールを呼び出すこと（`../../deployments/_templates/multi-account-org/` 参照）。
