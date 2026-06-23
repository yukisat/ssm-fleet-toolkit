# Changelog

このリポジトリの主要な変更を記録します。
Semantic Versioning 風: MAJOR.MINOR.PATCH（破壊的変更 / 機能追加 / 修正）。

## [Unreleased]

### Added

- Athena 権限を最小化し、専用結果バケットの作成に対応
  - inline policy をテンプレート化（`claude-investigator-athena.json.tftpl`）し、許可リージョンを
    `athena_regions`（= `primary_region` + `document_regions`）から自動生成（ベタ書き廃止）
  - 結果バケットは toolkit 専用名 `ssm-fleet-athena-results-*` のみ作成・利用可能に限定
    （`s3:CreateBucket` 等を当該プレフィックス＋許可リージョンに絞り、既存任意バケットは使わせない）
  - 取得系・Glue 読み取りは `ReadOnlyAccess` に委ね、inline policy からは除外して最小化
- SSM Document のマルチリージョン展開に対応（`document_regions` 変数）
  - `deployments/_template` に primary_region 以外へ Document を登録する仕組みを追加
  - opt-in リスト（例 `["us-west-2"]`）で必要なリージョンにだけ `claude-investigate-*` を登録・共有
  - primary の `module.doc` は不変のため既存リージョンの Document には影響しない
  - provider は Terraform の制約上リージョンごとに明示定義（us-west-2 / us-east-1 / ap-southeast-1 / ap-northeast-3 / eu-west-1 を同梱、追加は main.tf に provider + module を足す）

### Playbook hardening (AWS ベストプラクティス反映)

- ページネーション規約を `playbooks/README.md` に明文化
  - 調査系 API は `--no-paginate` を使わず CLI オートページネーションか NextToken ループ必須
  - `metadata.yaml` に `pagination` フィールドを追加（API ごとの上限・トークン名）
- 対象 playbook を更新:
  - `ec2/describe-by-tag`: describe-instances（max 1000）/ describe-instance-information（max 50）の NextToken ループ手順追加
  - `cloudwatch/alb-5xx-rate`: get-metric-data の NextToken ループ手順追加
- Athena コスト制御を `athena/cloudfront-top-uri` に組み込み
  - 専用 WorkGroup `ssm-fleet-investigator` で `BytesScannedCutoffPerQuery: 10 GiB`、`EnforceWorkGroupConfiguration`、結果バケット暗号化、CloudWatch メトリクス出力
  - 事前ドライランで実績スキャン量を線形外挿してから本番実行する手順
  - 実績スキャン量の事後確認手順
  - `metadata.yaml` に `cost_controls` フィールド追加
- `playbooks/README.md` に「ページネーション」「Athena コスト制御」共通規約セクション追加

### Scope (Breaking change: SSO + Organizations 一本化)

- サポート環境を **AWS Organizations + AWS Identity Center (SSO)** 統合済み環境のみに絞り込み
- 削除: `deployments/_templates/single-account/`、`deployments/_templates/multi-account-manual/`
- 改名: `deployments/_templates/multi-account-org/` → `deployments/_template/`
- `bootstrap/03-init-deployment.sh` から `--type` オプションを削除（テンプレートは 1 種類のみ）
- `bootstrap/00-check-prerequisites.sh` で Organizations 未利用時は即終了
- README / architecture / faq / what-this-does / coexistence / glossary / SKILL を SSO 前提に統一
- 単一アカウント / 手動マルチが必要な場合はフォークでの対応を推奨と明記

### Security / Hardening (外部レビュー反映)

- Document パラメータに `allowedPattern` を追加してインジェクション防御層を追加
  - 対象: mysql/slow-log, nginx/access-log, nginx/error-log, nginx/cve-pattern-scan,
    os/journalctl, os/process-list, os/system-messages, php-fpm/slow-log, php/error-log
- `bootstrap/installer-policy.json` の SSO ワイルドカード権限を最小化
  - `sso:*` / `sso-directory:*` / `identitystore:*` を削除
  - 実際に必要な 23 個の sso アクション + 6 個の identitystore 読み取り専用に絞る
- `bootstrap/02-create-tf-backend.sh` の `eval "$@"` を廃止、配列引数の直接実行に変更
  - PROFILE / REGION / BUCKET の入力値バリデーションを追加（インジェクション対策）

### Fixed

- README.md のライセンス欄を MIT に修正
- CLAUDE.md の docs/contributing.md「未作成」記述を削除
- ssm-fleet-setup/SKILL.md の bootstrap スクリプト参照を実在のものに修正

### Docs

- docs/required-permissions.md に SSO 権限の影響範囲と緩和策の警告セクション追加

### Planned

- Document 追加: nginx-config の構文チェック、mysql databases 一覧、wordpress エラーログ
- playbook 追加: CloudFront error-rate, S3 storage-by-bucket, RDS connection-count
- GitHub Template Repository 有効化（限定共有フェーズへの移行タイミング）
- 実環境での実証
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
