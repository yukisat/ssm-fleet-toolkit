---
name: ssm-fleet-setup
description: |
  ssm-fleet-toolkit を AWS 環境に導入する対話型セットアップスキル。
  単一アカウント / Organizations / 手動マルチアカウント の 3 環境タイプに対応し、
  Document・権限・StackSet の配布を Terraform 経由で行う。
---

# ssm-fleet-setup スキル

## トリガー

- 「ssm-fleet-toolkit を導入したい」
- 「このリポジトリをセットアップして」
- 「SSM Document 配布の仕組みを作りたい」

## 基本原則

1. **AWS への書き込み操作は必ず利用者の明示承認後**
2. **AWS CLI コマンドの自由構築禁止**。`bootstrap/` 配下のスクリプトのみ実行
3. **plan mode を活用**して全工程を承認後に実行
4. **監査ログ**: 全アクションを `install-audit.log` に追記

## ワークフロー

### Step 0: 全体提示（plan mode）

plan mode で以下を提示し、利用者の承認を得る:

- 環境タイプ（単一 / Organizations / 手動マルチ）
- 作成されるリソース一覧
- 必要な IAM 権限（`bootstrap/installer-policy.json` 参照）
- 想定コスト
- 所要時間
- ロールバック手順（`docs/rollback.md` 参照）

利用者が ExitPlanMode で承認するまで実際の処理は開始しない。

### Step 1: 環境タイプの判定

AskUserQuestion で確認:

- 単一 AWS アカウント
- AWS Organizations（推奨）
- 手動マルチアカウント（Organizations 未使用）

### Step 2: 前提条件チェック

`./bootstrap/00-check-prerequisites.sh` を実行。
不足項目があれば利用者に承認を得てから個別に修復:

- StackSets trusted access 未有効 → `01-enable-stacksets-trusted.sh`
- SSO 未ログイン → 利用者に `aws sso login` を依頼

### Step 3: 既存リソースとの衝突チェック

`./bootstrap/pre-flight-check.sh` を実行。
衝突があれば中止し、利用者と方針を相談（別名指定 or import）。

### Step 4: 委任管理アカウントの選定（Organizations の場合）

SSO で利用可能なアカウント一覧から利用者に選ばせる。
推奨基準を提示:

- セキュリティ・監査用の独立アカウント が望ましい
- アクセス頻度が低いアカウントが望ましい
- 既に管理機能を集約している場合はそちらに統合

### Step 5: Terraform backend の準備

S3 バケット + DynamoDB テーブルを委任管理アカウントに作成。
利用者の承認後、`02-create-tf-backend.sh`（未作成）を実行。

### Step 6: deployments/<org>/ の生成

`./bootstrap/03-init-deployment.sh`（未作成）で
`deployments/_templates/<type>/` をコピーし変数を埋める。

### Step 7: Terraform 実行

各段階で `terraform plan` を提示し承認を得てから `apply`:

1. permission set 関連
2. SSM Document 登録（管理アカウント）
3. IAM ロール StackSet 配布（子アカウント）
4. Document 共有設定（permissions）

各 plan は `0 to change, 0 to destroy` であることを必ず確認・報告。

### Step 8: 動作確認

テストインスタンスに対して `claude-investigate-os-disk-usage` を実行し、
正常応答が返ることを確認。

### Step 9: 完了報告

- 作成されたリソース一覧
- 監査ログのパス（`install-audit.log`）
- 次にできること（`/ssm-fleet-investigate` の使い方）
- インストーラ権限の削除推奨

## 安全ゲート

以下の操作前は必ず利用者の明示承認を得る:

- AWS Organizations の trusted access 有効化
- S3 バケット / DynamoDB テーブル作成
- IAM ロール / Policy 作成
- StackSet 作成 + 子アカウントへのインスタンス展開
- SSM Document 登録・共有
- terraform apply（plan 提示後）

## エラー対応

- 失敗時は即停止、現在の状態を `install-audit.log` に記録
- 部分的に作成されたリソースは利用者に提示（rollback で削除可能）
- ネットワーク・権限エラーは原因を切り分けて報告

## 参考ファイル

- `bootstrap/installer-policy.json`: 必要な IAM 権限
- `docs/required-permissions.md`: 権限の詳細
- `docs/rollback.md`: 撤退手順
- `docs/what-this-does-not-do.md`: スコープ外
- `docs/coexistence.md`: 既存環境との共存設計
