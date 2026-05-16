# ssm-fleet-toolkit

AWS SSM Document と調査用 IAM 権限を汎用ライブラリとして配布するテンプレート。
利用者は Claude Code 経由で導入・運用する想定。

## 利用者の意図と起動するスキル

| 利用者の発言 | 起動するスキル |
|---|---|
| 「導入したい」「セットアップ」 | `.claude/skills/ssm-fleet-setup/` |
| 「環境を調査して」「サーバー見て」 | `.claude/skills/ssm-fleet-investigate/` |
| 「Document を追加したい」 | `.claude/skills/ssm-fleet-add-document/` |

スキル起動後は SKILL.md の指示に従う。

## 絶対に守る制約

- Document は readonly のみ。`documents/stateful/` への追加は禁止
- Document 名は `claude-investigate-*` プレフィックス必須
- AWS への書き込み操作（terraform apply、aws CLI write 系）は必ず差分を提示し、利用者の明示的承認を得てから実行
- AWS CLI コマンドの自由構築は禁止。`bootstrap/` 配下の事前定義スクリプトのみ実行
- 顧客固有情報（アカウント ID、ドメイン、顧客名）をライブラリ層（`documents/`, `modules/`, `playbooks/`）にコミットしない

## 構造

- `documents/`: SSM Document ライブラリ（OS 内部調査）
- `playbooks/`: AWS API 調査の手順書（Athena・CloudWatch 等）
- `modules/`: Terraform モジュール（Document 配布・SSO permission set・IAM StackSet）
- `deployments/_template/`: 利用者環境のひな形（SSO + Organizations 専用）
- `bootstrap/`: 事前定義スクリプト群（IAM ポリシー JSON 同梱）
- `.claude/skills/`: 運用スキル
- `catalog.json`: 自動生成インデックス（生成済みなら信頼できる情報源）
- `docs/`: 設計・安全ポリシー・FAQ

## 詳細の参照先

- 設計思想: `docs/architecture.md`
- 必要権限: `docs/required-permissions.md`
- やらないこと: `docs/what-this-does-not-do.md`
- 既存環境との共存: `docs/coexistence.md`
- ロールバック: `docs/rollback.md`
- Document 追加方法: `docs/contributing.md`

## 各サブディレクトリの追加ガイド

編集対象ごとに以下のサブ CLAUDE.md を必要時に参照:

- `documents/CLAUDE.md`: Document 追加・編集時
- `modules/CLAUDE.md`: Terraform モジュール編集時
