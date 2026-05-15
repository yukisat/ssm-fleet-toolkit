# FAQ

## 一般

### Q. これは何のツールですか？

AWS 環境でのサーバー調査・AWS 環境調査を Claude Code に任せるための基盤テンプレート。
SSM Document と AWS 調査手順（playbook）を汎用ライブラリとして配布し、Terraform で各組織にデプロイする。

### Q. なぜ Claude Code 専用なのですか？

Claude Code を前提に設計しているが、Document・playbook 自体は AWS 標準機能なので、他の AI/ツールからも呼び出し可能。スキル（`.claude/skills/`）部分が Claude Code 固有。

### Q. 必要なスキルレベルは？

- 利用者: Claude Code が使えれば OK（AWS CLI / Terraform を直接叩く必要なし）
- 導入担当: AWS の基本（IAM、Organizations、SSO）が分かるレベル

## 安全性

### Q. 本当に readonly ですか？

はい。提供する Document は全て readonly。インストーラ権限以外、AWS への書き込み権限は含まれません。詳細は `docs/what-this-does-not-do.md`。

### Q. Claude が想定外のことをしませんか？

設計上できません。
- Claude Code は `bootstrap/` 配下の事前定義スクリプトのみ実行
- AWS CLI コマンドの自由構築は CLAUDE.md で禁止
- terraform apply は plan 提示と承認を経てから実行

### Q. 既存環境を壊しませんか？

設計で構造的に保証しています:
- 全リソース名に `ssm-fleet-*` / `claude-investigate-*` プレフィックス
- 既存リソースは `data` source で参照のみ
- Terraform state は専用 backend に独立
- `terraform plan` で `0 to change, 0 to destroy` を確認

詳細: `docs/coexistence.md`

### Q. データはどこに行きますか？

- SSM Document 実行結果: 同一 AWS アカウント内（SSM の標準ログ）
- 取得結果の解釈: 利用者の Claude Code → Anthropic API へ送信される（Claude Code 利用の前提）
- 外部 API（Anthropic 以外）への送信: なし

## 導入

### Q. 導入にどれくらい時間がかかりますか？

- 単一アカウント: 約 10 分
- Organizations 統合: 約 15-20 分
- 複数アカウント手動: 約 20-30 分

### Q. 既に他の Terraform プロジェクトを使っています。共存できますか？

はい。`state` は専用バケットに分離、リソースは独自プレフィックスで管理。
詳細: `docs/coexistence.md`

### Q. SSO を使っていません。導入できますか？

はい。単一アカウントテンプレート（`deployments/_templates/single-account/`）は SSO 不要。
複数アカウントの場合も `multi-account-manual` テンプレートで対応可能（ただし IAM 配布は手動）。

### Q. Organizations を使っていますが、StackSets trusted access が無効です。

セットアップスキルが `bootstrap/01-enable-stacksets-trusted.sh` を提案します。
承認後に有効化されます（組織レベル設定、他リソースへの影響なし）。

### Q. 委任管理アカウントはどれを選べばいいですか？

推奨基準:
- セキュリティ・監査用に専用化されたアカウント
- アクセス頻度が低いアカウント（事故時の影響を抑える）
- 既に管理機能を集約しているアカウント

迷う場合は AWS の組織管理ベストプラクティスを参照、または既存の管理アカウントから始める。

## 運用

### Q. 新しい Document を追加したい

`.claude/skills/ssm-fleet-add-document/` スキルを起動するか、`docs/contributing.md` の手順に従う。

### Q. Document の対応 OS を増やしたい

`metadata.yaml` の `supported_os` を更新し、対象 OS で動作確認した上で PR。

### Q. オペレータ権限を最小化したい

`modules/sso-permission-set` の `include_athena` `include_cloudwatch` を `false` にすれば、SSM 実行権限のみに絞れます。

### Q. インストーラ権限を削除したい

セットアップ完了後、インストーラ専用 IAM ユーザー（または Permission Set）を削除可能。日常運用には不要。

### Q. ロールバックしたい

`docs/rollback.md` 参照。
- 推奨: `terraform destroy`
- 緊急: `bootstrap/99-rollback.sh`

## トラブル

### Q. terraform plan で `0 to change, 0 to destroy` 以外が出ました

要調査。`update in-place` / `destroy and replace` が出ているなら、想定外の変更が発生している可能性。
- 既存リソースを誤って参照していないか
- 別の Terraform プロジェクトと state が混ざっていないか

`apply` する前に必ず原因を特定。

### Q. StackSet 作成がエラーになります

よくある原因:
- trusted access が未有効 → `bootstrap/01-enable-stacksets-trusted.sh`
- 委任管理アカウントから組織全体への操作が制限されている → 管理アカウントから実行
- 他の StackSet 操作が並行実行中 → 待機してリトライ

### Q. SSM Document 実行で失敗します

- インスタンスが SSM Online か確認: `aws ssm describe-instance-information`
- IAM ロールがインスタンスにアタッチされているか確認
- ネットワーク到達性確認（VPC エンドポイントの場合 ssmmessages, ec2messages 必須）

### Q. SCP で操作が拒否されました

組織の SCP（Service Control Policy）がツール操作をブロックしている可能性。
組織管理者に必要なアクションの許可を依頼するか、SCP 例外を設ける。

## OSS 化

### Q. 公開はいつですか？

開発者の判断次第。汎用化と HEP 内実証が完了したタイミング（roadmap で言う Phase 4）。

### Q. ライセンスは？

OSS 公開時に決定。MIT or Apache 2.0 を想定。

### Q. 外部から PR を出したい

OSS 公開後に受け入れ予定。`docs/contributing.md` の規約に従う。
