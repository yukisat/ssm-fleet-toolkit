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

#### PyYAML が必要な理由とローカルでの用意

`build-catalog.sh` は metadata.yaml の入れ子フィールド（`pagination`, `cost_controls` 等）を正しく扱うために [PyYAML](https://pyyaml.org/) を使う。PyYAML がない環境では同梱の簡易パーサにフォールバックするが、簡易パーサは入れ子辞書に対応していないためそれらフィールドが `null` になり、CI の `--check` と差分が出る。

macOS のシステム Python は外部パッケージのインストールが制限されているので、`uv` で venv を作って実行するのが確実:

```bash
# 1 回だけ venv を用意（$TMPDIR は macOS の書き込み可能領域）
uv venv "$TMPDIR/venv"
VIRTUAL_ENV="$TMPDIR/venv" uv pip install pyyaml

# 以後の catalog 再生成
PATH="$TMPDIR/venv/bin:$PATH" ./scripts/build-catalog.sh
```

CI（`.github/workflows/checks.yml`）は `pip install pyyaml` を入れているのでこの差分は発生しない。

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

## シェル互換性ガイドライン

`bootstrap/` および `scripts/` 配下のローカル実行スクリプトは、利用者の対話シェル（bash / zsh）を問わず動作する必要がある:

### Shebang

- 必ず `#!/usr/bin/env bash` を指定する
- これにより利用者のシェルに関わらず bash で実行される

### bash 3.2（macOS デフォルト）互換性

macOS は標準で bash 3.2 を提供する（古い）。以下は使用しない:

- `mapfile` / `readarray`（4.0+）
- 連想配列 `declare -A`（4.0+）
- `${var,,}` / `${var^^}`（4.0+）
- `&>>` リダイレクト（4.0+、`>> file 2>&1` で代替）

### zsh から source する場合の配慮

- 配列展開は必ず `"${array[@]}"` で（zsh の word splitting 差異対策）
- グローブ展開に依存しない（`set -f` で抑制するか、明示的にループ）
- `compgen` は bash 専用、使わない

### POSIX 互換に寄せる

可能な限り POSIX shell 互換の書き方を選ぶ。bash 専用機能を使う場合はコメントで明示。

### SSM Document 内のシェルスクリプト

- 実行環境は EC2 上の `sh -c`（bash 利用可）
- マルチライン処理は `runCommand` 配列で 1 コマンド 1 要素にするか、heredoc を使う
- `{{ Parameter }}` 展開と shell 変数展開を混同しない（パラメータは最初に変数代入）

詳細: `docs/known-gotchas.md` 9-12 番

## レビュー観点

PR レビューでは以下を確認:

- [ ] readonly か（書き込み・破壊操作なし）
- [ ] 出力が機械可読 JSON か
- [ ] metadata.yaml が完備されているか
- [ ] 顧客固有情報が含まれていないか
- [ ] 命名規約に従っているか
- [ ] README に判定ヒントがあるか
- [ ] catalog.json が更新されているか
