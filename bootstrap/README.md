# bootstrap/

セットアップで実行する事前定義スクリプトと IAM ポリシー JSON。

## 設計原則

- **Claude Code は `bootstrap/` 配下のスクリプトのみを実行する**（自由な AWS CLI 構築は禁止）
- すべてのスクリプトは冪等（複数回実行しても安全）
- 各スクリプトは `--dry-run` をサポート（実行内容のみ表示）
- 1 スクリプト = 1 つの明確な責務、20-50 行以内を目安

## ファイル

### IAM ポリシー JSON

| ファイル | 用途 |
|---|---|
| `installer-policy.json` | セットアップ時のみ使う強い権限。完了後に削除可能 |
| 各機能の operator policy | `../modules/sso-permission-set/policies/` 配下に集約 |

### スクリプト

| スクリプト | 内容 | 副作用 |
|---|---|---|
| `00-check-prerequisites.sh` | AWS CLI / SSO / Organizations の前提確認 | なし（読み取りのみ） |
| `01-enable-stacksets-trusted.sh` | Organizations の StackSets trusted access 有効化 | あり（組織レベル設定） |
| `02-create-tf-backend.sh` | terraform backend 用 S3 + DynamoDB 作成 | あり（リソース作成） |
| `03-init-deployment.sh` | `deployments/<org>/` のひな形展開 | なし（ローカルファイルのみ） |
| `pre-flight-check.sh` | 既存リソースとの衝突チェック | なし（読み取りのみ） |
| `99-rollback.sh` | ssm-fleet-* 配下のリソース一括削除 | あり（削除） |

## 使い方

通常は Claude Code のセットアップスキル経由で起動されるが、
手動実行も可能:

```bash
./bootstrap/00-check-prerequisites.sh
./bootstrap/00-check-prerequisites.sh --dry-run  # 実行内容のみ表示
```

## 監査ログ

すべてのスクリプトは先頭で `_lib.sh` を source し、`audit_setup "$@"` で監査ログ機構を初期化する。リポジトリルートの `install-audit.log` に以下フォーマットで追記される（`.gitignore` 除外済み）:

```
<ISO 8601 UTC>\t<script-name>\t<event>\t<result>\t<details>
```

- `event`: 開始 (`start`) / 終了 (`exit`) / 任意のアクション識別子
- `result`: `ok` / `fail` / `skip` / `dry-run` / `info`
- `details`: 自由記述

`audit_setup` がスクリプト開始時と終了時（成功・失敗を自動判別）を自動記録する。スクリプト本体は重要なアクション直後に `audit_log <event> <result> [details]` を明示的に呼ぶ。

ログを確認:

```bash
column -t -s $'\t' install-audit.log | tail
```
