# Changelog

このリポジトリの主要な変更を記録します。
Semantic Versioning 風: MAJOR.MINOR.PATCH（破壊的変更 / 機能追加 / 修正）。

## [Unreleased]

### Added

- 追加 Document: php/version, php-fpm/pool-config, mysql/status, mysql/version,
  wordpress/core-version, wordpress/plugin-list, apache/version,
  os/load-average, os/network-connections, security/ssh-config
- 追加 playbook: cloudwatch/alb-5xx-rate, cloudwatch/ec2-cpu-stats, ec2/describe-by-tag
- LICENSE (MIT)
- SECURITY.md
- docs/audit-trail.md, docs/glossary.md, docs/known-gotchas.md
- docs/schemas/metadata.schema.json (metadata.yaml の検証用)
- .github/workflows/checks.yml (terraform fmt -check, catalog --check, shellcheck)
- deployments/_templates/multi-account-manual の Terraform 実装

### Changed

- build-catalog.sh: PyYAML 必須から、簡易 YAML パーサにフォールバック対応

## [0.2.0] - 2026-05-16

### Added

- bootstrap/02-create-tf-backend.sh (S3 + DynamoDB 作成)
- bootstrap/03-init-deployment.sh (deployment テンプレ展開)
- modules/iam-stackset (CloudFormation StackSet による IAM ロール配布)
- documents/readonly/claude-investigate/os/memory-usage
- documents/readonly/claude-investigate/os/process-list
- documents/readonly/claude-investigate/nginx/version
- playbooks/readonly/athena/cloudfront-top-uri
- scripts/build-catalog.sh (catalog.json 自動生成)
- docs/contributing.md
- docs/faq.md

## [0.1.0] - 2026-05-16

### Added

- 初期スケルトン生成
- CLAUDE.md, README.md, .gitignore
- documents/ ディレクトリ構造 + サンプル disk-usage
- modules/ssm-document, modules/sso-permission-set
- bootstrap/ 配下のスクリプト雛形と installer-policy.json
- .claude/skills/ の 3 スキル雛形
- docs/ 主要ドキュメント
- deployments/_templates/ の 3 環境タイプ雛形
- catalog.json 初期版
