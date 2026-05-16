# ssm-fleet-toolkit

AWS SSO + Organizations 統合環境向けに、AWS SSM Document と Claude Code スキルを汎用ライブラリとして配布するテンプレートリポジトリ。

サーバー / AWS 環境の調査を Claude Code に任せて、運用負荷を下げることを目的とする。

## 想定する環境

- **AWS Organizations** 配下の複数アカウントを運用
- **AWS Identity Center (SSO)** 統合済み
- 委任管理アカウントから Document を集約配信

単一アカウント運用や Organizations 未利用環境は対象外。これらが必要な場合はフォークして別リポジトリで対応してください。

## 何ができるか

- OS 内部調査（ディスク・プロセス・nginx・PHP・MySQL など）を SSM Document 経由で実行
- AWS 環境調査（Athena・CloudWatch・EC2 describe など）を統一インターフェースで実行
- Organizations 全アカウントへの Document 配布を Terraform で管理
- SSO Permission Set による調査用権限の最小化配布
- 既存 AWS 環境を一切壊さず後から追加可能

## 導入方法

Claude Code から導入する想定:

1. このリポジトリを GitHub の "Use this template" で複製、または `git clone`
2. clone 先で Claude Code を起動
3. 「ssm-fleet-toolkit をセットアップして」と伝える

セットアップスキルが対話的に環境を判定し、必要な作業を実行する。利用者が AWS CLI や Terraform コマンドを直接叩く必要はない。

## 安心設計

AWS 管理権限を持つ導入担当者が安心して導入できるよう、以下を構造的に保証する:

- セットアップ前にすべての作業内容を提示し、承認を求める
- 各ステップでスクリプトの中身を提示し、いつでも中止できる
- Claude Code が独自に AWS CLI を組み立てない（事前定義スクリプトのみ実行）
- 強い権限は使い捨て可能、運用時は最小権限のみ
- 全アクションは `install-audit.log` に記録される
- ワンコマンドで完全ロールバック可能
- 既存 AWS リソースには一切触れない（`ssm-fleet-*` / `claude-investigate-*` プレフィックスのみ管理）

詳細: [docs/required-permissions.md](docs/required-permissions.md) / [docs/what-this-does-not-do.md](docs/what-this-does-not-do.md) / [docs/coexistence.md](docs/coexistence.md)

## 詳細

- アーキテクチャ: [docs/architecture.md](docs/architecture.md)
- 利用可能な Document 一覧: [catalog.json](catalog.json)
- 安全ポリシー: [docs/safety-policy.md](docs/safety-policy.md)
- 既存環境との共存: [docs/coexistence.md](docs/coexistence.md)
- ロールバック: [docs/rollback.md](docs/rollback.md)

## ライセンス

[MIT License](LICENSE)
