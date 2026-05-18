# ssm-fleet-toolkit

AWS SSO + Organizations 統合環境向けに、AWS SSM Document と Claude Code スキルを汎用ライブラリとして配布するテンプレートリポジトリ。

サーバー / AWS 環境の調査を Claude Code に任せて、運用負荷を下げることを目的とする。

## 想定する環境

- **AWS Organizations** 配下の複数アカウントを運用
- **AWS Identity Center (SSO)** 統合済み
- 委任管理アカウントから Document を集約配信

単一アカウント運用や Organizations 未利用環境は [yukisat/ssm-fleet-toolkit-single](https://github.com/yukisat/ssm-fleet-toolkit-single) を使ってください。

## 何ができるか

- OS 内部調査（ディスク・プロセス・nginx・PHP・MySQL など）を SSM Document 経由で実行
- AWS 環境調査（Athena・CloudWatch・EC2 describe など）を統一インターフェースで実行
- Organizations 全アカウントへの Document 配布を Terraform で管理
- SSO Permission Set による調査用権限の最小化配布
- 既存 AWS 環境を一切壊さず後から追加可能

## セットアップ（導入担当者向け）

AWS 環境への初回導入。Organizations / SSO / Terraform の設定を行う。**管理権限を持つ担当者が一度だけ実施する。**

```bash
git clone https://github.com/yukisat/ssm-fleet-toolkit.git
cd ssm-fleet-toolkit
claude  # Claude Code を起動
```

Claude Code が起動したら:

```
ssm-fleet-toolkit をセットアップして
```

セットアップスキルが対話的に環境を判定し、必要な作業を順番に案内する。AWS CLI や Terraform コマンドを直接叩く必要はない。完了まで約 30〜60 分。

## 調査の開始（利用者向け）

セットアップ完了後、調査を行うメンバーは以下の手順で開始する。

```bash
git clone https://github.com/yukisat/ssm-fleet-toolkit.git
cd ssm-fleet-toolkit
claude  # Claude Code を起動
```

Claude Code が起動したら:

```
ssm-fleet-investigate を使いたい
```

または調査したい内容をそのまま伝える:

```
a-1234 のディスク使用量を確認して
```

```
本番アカウントの当月コストをサービス別に出して
```

スキルが catalog から適切な調査手段を選んで実行する。

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
