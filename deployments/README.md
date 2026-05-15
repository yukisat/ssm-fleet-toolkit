# deployments/

利用者環境ごとの Terraform 設定を配置するディレクトリ。

## サブディレクトリ

- `_templates/`: 環境タイプ別のひな形（テンプレート用、実値を入れない）
  - `single-account/`: 単一 AWS アカウント
  - `multi-account-org/`: AWS Organizations 統合
  - `multi-account-manual/`: 複数アカウント手動管理

## 利用者の使い方

1. このリポジトリを GitHub Template から複製、または `git clone`
2. `_templates/<your-env-type>/` を `<your-org-name>/` にコピー
3. `terraform.tfvars.example` を `terraform.tfvars` にコピーして実値を記入
4. `terraform init` → `plan` → `apply`

通常は Claude Code のセットアップスキル（`.claude/skills/ssm-fleet-setup/`）が自動的に行うため、手動操作は不要。

## .gitignore

`*.tfvars` はデフォルトで gitignore 対象。**実値が誤って公開されないよう必ず確認**。

各組織の deployments は組織のプライベートリポジトリで管理し、このテンプレートリポジトリには `_templates/` のみが含まれる前提。
