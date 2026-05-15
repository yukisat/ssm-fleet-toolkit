# このツールが提供すること

ssm-fleet-toolkit が**やること**を平易に説明します（やらないことは `what-this-does-not-do.md`）。

## 一言で

- **AWS 環境のサーバー調査と AWS リソース調査を Claude Code に任せる仕組み**
- **誰でも導入でき、誰でも安全に使える形でテンプレート化**

## 提供する 3 つの価値

### 1. 調査の Document 化

SSM Document として「ディスク確認」「nginx バージョン確認」等の調査手順を配布。
利用者は Claude Code に「ディスク見て」と言うだけで、Claude が適切な Document を選んで実行する。

### 2. AWS 環境調査の playbook 化

Athena, CloudWatch, EC2 describe 等の AWS API 経由の調査も同じ枠組みで管理。
SSM Document（OS 内部）と playbook（AWS 環境）を組み合わせた統合調査が可能。

### 3. 安全な権限管理

調査に必要な最小権限を SSO Permission Set として Terraform で配布。
機能フラグで「SSM だけ」「+ Athena」「+ CloudWatch」を選択可能。

## 利用者が得るもの

### 導入後にできるようになること

- 「サイト遅い」「500 エラー多発」等の問い合わせを Claude に投げて一次調査が完結
- 複数アカウント横断で同じコマンドで調査
- 調査履歴が CloudTrail に残り後追い可能
- 顧客サポートのリードタイム短縮

### 導入時のコスト

- 月額 $1 未満（S3 state + DynamoDB lock）
- セットアップ作業時間 15-30 分
- 学習コスト最小（Claude Code に依頼するだけ）

## 適用範囲

### よく使うシナリオ

- WordPress / PHP 系サイトの構成調査
- nginx / Apache の設定確認
- CVE 影響範囲調査（設定パターンスキャン）
- アクセスログ解析（Athena 経由）
- インフラチームの定期監査

### 適合しないシナリオ

- 大規模ログ集約（CloudWatch Logs Insights / Athena を直接使った方が良い）
- リアルタイム監視（CloudWatch Alarms / Datadog 等）
- セキュリティインシデント対応の自動修復（本ツールは調査のみ）

## 利用形態

### 想定パターン A: 個人 / 小組織

- 単一アカウント
- Permission Set ではなく IAM ロールに直接アタッチ
- `deployments/_templates/single-account/` を使う

### 想定パターン B: AWS Organizations 利用組織

- 複数アカウントを Organizations で管理
- 委任管理アカウントから StackSet で IAM 配布
- SSO Permission Set でグループ単位の権限管理
- `deployments/_templates/multi-account-org/` を使う

### 想定パターン C: 複数アカウントだが Organizations 未使用

- 個別のアカウントに対して手動配布
- 一部機能（StackSet）は使えない
- `deployments/_templates/multi-account-manual/` を使う

## エコシステム

### 同梱されるもの

- Document ライブラリ（汎用、誰でも使える）
- playbook ライブラリ（同上）
- Terraform モジュール（配布の仕組み）
- Claude Code スキル（対話的セットアップ・調査・追加）
- bootstrap スクリプト（事前定義、安全な実行）
- 各種 docs

### 外部依存

- AWS（必須）
- Claude Code（必須、利用形態として）
- Terraform 1.5+ （必須）
- Python 3 + PyYAML（オプション、catalog 自動生成時）

## 既存ツールとの違い

| ツール | 違い |
|---|---|
| AWS Systems Manager 単体 | Document 集約・配布の仕組みがない |
| Ansible | エージェント不要、AWS ネイティブ |
| CloudShell | マルチアカウント横断・読み取り専用に特化 |
| Datadog 等の SaaS | 月額不要、自前 AWS リソース内で完結 |
| AWS Config | 設定変更検知ではなく、調査主導 |
