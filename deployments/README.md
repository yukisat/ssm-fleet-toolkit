# deployments/

利用者環境ごとの Terraform 設定を配置するディレクトリ。

## 構成

- `_template/`: 利用者がコピーする雛形（SSO + Organizations 専用、実値は入れない）

## 利用者の使い方

1. このリポジトリを GitHub Template から複製、または `git clone`
2. `_template/` を `<your-org-name>/` にコピー
3. `terraform.tfvars.example` を `terraform.tfvars` にコピーして実値を記入
4. `terraform init` → `plan` → `apply`

通常は Claude Code のセットアップスキル（`.claude/skills/ssm-fleet-setup/`）が自動的に行うため、手動操作は不要。

## .gitignore

`*.tfvars` はデフォルトで gitignore 対象。**実値が誤って公開されないよう必ず確認**。

各組織の deployments は組織のプライベートリポジトリで管理し、このテンプレートリポジトリには `_template/` のみが含まれる前提。

## サポート範囲

このリポジトリは **AWS Organizations + AWS Identity Center (SSO) 統合済み環境**のみをサポート。
単一アカウント運用や Organizations 未利用環境が必要な場合はフォークして対応してください。
