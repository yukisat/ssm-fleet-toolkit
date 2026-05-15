# コントリビューションガイド

## 何を増やしたいか

このリポジトリは「インフラ事業者が誰でも使える調査基盤」を目指します。歓迎する貢献:

- 新しい readonly な SSM Document（OS / nginx / php / mysql 等）
- 新しい AWS 調査 playbook（Athena / CloudWatch 等）
- ドキュメント改善、FAQ 追加
- Terraform モジュールの汎用性向上
- セットアップスキルの対話改善

## 受け入れない貢献

- **stateful な Document の追加**（`docs/safety-policy.md` 参照）
- **顧客固有情報の混入**（アカウント ID、顧客名、ドメイン、IP）
- **書き込み権限の付与**（IAM ポリシーの拡張）
- 認証情報やシークレットを含む変更

## Document 追加の手順

### 1. 命名と配置

- ディレクトリ: `documents/readonly/claude-investigate/<category>/<name>/`
- Document 名: `claude-investigate-<category>-<name>`（kebab-case）
- 3 ファイル必須: `document.yaml`, `metadata.yaml`, `README.md`

### 2. 命名規約

```
カテゴリ例: os / nginx / php / wordpress / mysql / apache / redis / security / php-fpm
名前例:    disk-usage / process-list / version / vhost-list / slow-log-tail
```

### 3. document.yaml の作法

- `schemaVersion: "2.2"`
- `action: aws:runShellScript` を基本とする
- 出力は **JSON 形式**（機械可読）
- `set -eu` でエラーで即停止
- 危険コマンド（rm, chmod, kill, systemctl reload 等）禁止
- パラメータは可能な限り正規化（パス、TopN 等）

### 4. metadata.yaml 必須フィールド

```yaml
name: claude-investigate-<category>-<name>
category: <category>
subcategory: <subcategory>  # 任意
safety: readonly  # readonly 以外は受け入れ不可
description: |
  この Document が何を調べるか
supported_os:
  - amazon-linux-2
  - ubuntu-22.04
  # 等
required_packages: []
required_commands:
  - <必要コマンド>
parameters:
  - name: <ParamName>
    type: string
    default: <default>
    description: <説明>
output_schema:
  type: object  # または array
  properties:
    # JSON Schema 風に
estimated_runtime_seconds: 1
claude_hints: |
  Claude が結果を解釈するためのヒント
  - 警告レベルの目安
  - 異常パターンの判断基準
```

### 5. README.md の構成

- 何をするか（1 段落）
- 使い方（aws ssm send-command 例）
- パラメータ説明
- 出力例（JSON）
- 判定ヒント
- 関連 Document へのリンク

### 6. catalog.json の更新

```bash
./scripts/build-catalog.sh
```

metadata.yaml から自動生成される。

### 7. テスト

- 検証環境のインスタンスで実行し、出力スキーマと一致するか確認
- 複数 OS（少なくとも AL2 と AL2023）で動作確認

### 8. PR

- ブランチ名: `add-document-<category>-<name>` 等
- PR 本文に動作確認結果のスクショまたはログを含める

## Playbook 追加の手順

### 1. 配置

- `playbooks/readonly/<aws-service>/<name>/`
- 3 ファイル: `metadata.yaml`, `query.sql`（または `commands.md`）, `playbook.md`

### 2. metadata.yaml

```yaml
name: <service>-<name>
category: <service>
safety: readonly
description: |
  何を調べるか
required_permissions:
  - <AWS アクション>
required_resources:
  # 利用者環境に必要なリソース
parameters: []
output_schema: {}
estimated_runtime_seconds: 30
estimated_cost_usd: 0.01  # コストが発生する場合
claude_hints: |
  結果解釈ヒント
```

### 3. playbook.md

実行手順を明示的に記述。Claude が読んでそのまま実行できる粒度。

## Terraform モジュールの改善

- 既存モジュールに変数を追加する場合、デフォルト値で後方互換を保つ
- breaking change は別ブランチで提案、利用者影響を明記
- `modules/CLAUDE.md` の規約を守る

## ローカル検証

```bash
# Terraform 構文チェック
terraform fmt -recursive
terraform validate

# Document スクリプトの shellcheck
shellcheck documents/**/*.yaml  # YAML 内の bash も対象に

# catalog 整合性チェック
./scripts/build-catalog.sh --check
```

## レビュー観点

PR レビューでは以下を確認:

- [ ] readonly か（書き込み・破壊操作なし）
- [ ] 出力が機械可読 JSON か
- [ ] metadata.yaml が完備されているか
- [ ] 顧客固有情報が含まれていないか
- [ ] 命名規約に従っているか
- [ ] README に判定ヒントがあるか
- [ ] catalog.json が更新されているか
