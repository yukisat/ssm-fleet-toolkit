# Changelog

このリポジトリの主要な変更を記録します。
Semantic Versioning 風: MAJOR.MINOR.PATCH（破壊的変更 / 機能追加 / 修正）。

## [Unreleased]

### Planned

- Document 追加: nginx-config の構文チェック、mysql databases 一覧、wordpress エラーログ
- playbook 追加: CloudFront error-rate, S3 storage-by-bucket, RDS connection-count
- GitHub Template Repository 有効化（HEP 展開タイミング）
- Amimoto 実環境での実証
- `bootstrap/02-create-tf-backend.sh` の dry-run 詳細化

## [0.3.0] - 2026-05-16

### Added

- 追加 Document:
  - **os**: load-average, network-connections, listening-ports, journalctl, system-messages
  - **nginx**: access-log, error-log, config, vhost-list, cve-pattern-scan
  - **php**: version, error-log
  - **php-fpm**: pool-config, slow-log
  - **mysql**: version, status, slow-log
  - **wordpress**: core-version, plugin-list, multisite-check
  - **apache**: version
  - **security**: ssh-config
- 追加 playbook:
  - **cloudwatch**: alb-5xx-rate (metadata + playbook.md)
  - **cloudwatch**: ec2-cpu-stats (metadata + playbook.md)
  - **ec2**: describe-by-tag (metadata + playbook.md)
- LICENSE (MIT)
- SECURITY.md（脆弱性報告ポリシー）
- CHANGELOG.md
- docs:
  - audit-trail.md（監査ログ運用）
  - what-this-does.md（提供する価値）
  - security-model.md（脅威モデル）
  - known-gotchas.md（18 個の運用落とし穴）
  - glossary.md（用語集）
  - schemas/metadata.schema.json（JSON Schema）
- .github/workflows/checks.yml（CI: terraform fmt + validate, shellcheck, yaml syntax, catalog --check）

### Changed

- scripts/build-catalog.sh:
  - PyYAML 不要のフォールバックパーサ追加
  - インラインリスト `[a, b, c]` 形式に対応
  - `$TMPDIR` 利用に変更（sandbox 互換性）
- docs/contributing.md にシェル互換性ガイドライン追加（bash 3.2 / zsh 対応）
- catalog.json を 26 Documents + 4 playbook に更新

## [0.2.0] - 2026-05-16

### Added

- bootstrap/02-create-tf-backend.sh（S3 バケット + DynamoDB テーブル作成、冪等）
- bootstrap/03-init-deployment.sh（deployments/ をテンプレートから生成）
- modules/iam-stackset（CloudFormation StackSet で子アカウントに IAM ロール配布）
- 追加 Document:
  - os/memory-usage
  - os/process-list
  - nginx/version
- 追加 playbook:
  - athena/cloudfront-top-uri
- scripts/build-catalog.sh（catalog.json 自動生成）
- docs/contributing.md（Document/playbook 追加手順）
- docs/faq.md（Q&A 集）

## [0.1.0] - 2026-05-16

### Added

- 初期スケルトン生成
- CLAUDE.md（35 行、利用者意図とスキル起動の対応表）
- README.md（Claude Code 経由の導入を誘導）
- .gitignore（Terraform / シークレット系除外）
- documents/ ディレクトリ構造 + サンプル disk-usage
- modules/ssm-document（Document 登録 + permissions 共有）
- modules/sso-permission-set（機能フラグで inline policy 合成）
- bootstrap/ 配下のスクリプト雛形と installer-policy.json
- .claude/skills/ の 3 スキル雛形（setup / investigate / add-document）
- docs/ の主要ドキュメント（architecture / required-permissions / what-this-does-not-do / coexistence / rollback / safety-policy）
- deployments/_templates/ の 3 環境タイプ雛形
- catalog.json 初期版
