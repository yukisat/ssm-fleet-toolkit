# Document 編集ガイド

## ディレクトリの意味

- `readonly/`: 状態を変更しない調査専用 Document
- `stateful/`: 現在空。追加禁止（理由は `../docs/safety-policy.md`）

## 新規 Document を追加する

`.claude/skills/ssm-fleet-add-document/` スキル経由で追加すること。
手動追加はメタデータ整合性が崩れるため非推奨。

## 命名規約

- ディレクトリ: `readonly/claude-investigate/<category>/<name>/`
- Document 名: `claude-investigate-<category>-<name>`
- カテゴリ例: os / nginx / php / wordpress / mysql / apache / redis / security

## 必須ファイル

各 Document ディレクトリに以下を配置:

- `document.yaml`: SSM Document 本体（YAML 形式推奨）
- `metadata.yaml`: 機械可読メタデータ（catalog.json の元）
- `README.md`: 人間向け説明（任意だが推奨）

## metadata.yaml 必須フィールド

```yaml
name: claude-investigate-<category>-<name>
category: <category>
safety: readonly
description: |
  この Document が何を調べるかの説明
supported_os:
  - amazon-linux-2
  - amazon-linux-2023
  - ubuntu-22.04
required_packages: []
parameters: []
output_schema: { ... }
claude_hints: |
  Claude が結果を解釈するためのヒント
estimated_runtime_seconds: 1
```

詳細スキーマと例は `../docs/contributing.md`（未作成）または既存の Document ディレクトリを参照。

## カテゴリ追加時

新カテゴリを作る場合は `../catalog.json` への反映と、必要なら `../.claude/skills/ssm-fleet-investigate/SKILL.md` の更新も検討。
