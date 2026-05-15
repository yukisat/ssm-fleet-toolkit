# セキュリティポリシー

## 脆弱性報告

このプロジェクトに脆弱性を発見した場合は、**Issue ではなく以下の方法で報告**してください:

- GitHub の Private Security Advisories 機能（リポジトリ Security タブ → Report a vulnerability）
- またはメンテナへの直接連絡

公開 Issue では報告しないでください。

## 報告に含めてほしい内容

- 影響範囲（どのバージョン・どのコンポーネント）
- 再現手順
- 想定される影響
- 可能であれば修正案

## 対応プロセス

1. 受領確認: 3 営業日以内
2. 影響評価: 7 営業日以内
3. 修正: 重要度に応じて
4. 公開: 利用者が更新できる状態になってから

## サポートバージョン

最新の main ブランチのみサポート。
タグリリース運用は将来対応予定。

## このプロジェクトの設計上の安全性

詳細は以下を参照:

- [docs/safety-policy.md](docs/safety-policy.md): 安全ポリシー
- [docs/what-this-does-not-do.md](docs/what-this-does-not-do.md): スコープ外
- [docs/coexistence.md](docs/coexistence.md): 既存環境との非破壊性

## 脅威モデル

主な脅威と緩和策:

| 脅威 | 緩和策 |
|---|---|
| 不正な Document 追加 | readonly 限定、PR レビュー必須、IAM ポリシーのリソース絞り込み |
| 過剰な権限付与 | 機能フラグで opt-in、最小権限原則 |
| 既存環境への意図しない変更 | プレフィックスベースのリソース命名、Terraform state 分離 |
| 認証情報漏洩 | .gitignore でシークレット系を除外、`.envrc` `.tfvars` を追跡対象外 |
| Claude による暴走 | 事前定義スクリプトのみ実行、書き込み操作は承認制 |
