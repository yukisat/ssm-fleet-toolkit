# Terraform Module: ssm-document

SSM Document を登録し、必要に応じて他 AWS アカウントへ共有する汎用モジュール。

## 使い方

Organizations 全アカウントへの共有が標準パターン:

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

## 設計

- `document_name` は `claude-investigate-` プレフィックス必須（validation あり）
- `safety` は `readonly` のみ許可（stateful Document をこのモジュールで登録できない安全策）
- タグで `ssm-fleet:managed-by`, `ssm-fleet:category`, `ssm-fleet:safety` を自動付与
- `shared_account_ids` が空配列なら `permissions` リソースを生成しない実装になっているが、本リポジトリでは Organizations 全アカウント共有が前提運用

## マルチリージョン展開

このモジュールは単一リージョンに登録する。複数リージョンに同じ Document を登録したい場合は、provider alias で対象リージョンごとにモジュールを呼び出すこと（`../../deployments/_template/` 参照）。
