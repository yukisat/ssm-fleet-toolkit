# Terraform モジュール編集ガイド

## このディレクトリ

汎用 Terraform モジュール。組織固有の値（アカウント ID、ドメイン、顧客名）を含めないこと。

## モジュール一覧

- `ssm-document/`: SSM Document の登録 + permissions による共有
- `sso-permission-set/`: AWS SSO permission set + inline policy 合成
- `iam-stackset/`: 子アカウントへの IAM ロール CloudFormation StackSet 配布

## 編集時の確認

- 変数追加時は `variables.tf` に `description` と妥当なデフォルト値を必ず記載
- breaking change の場合は `../CHANGELOG.md`（未作成）に記載
- マルチアカウント対応のため `account_ids` 変数は空配列でも動作すること（空なら permissions リソース不生成）
- リソース名は `ssm-fleet-*` または `claude-investigate-*` プレフィックス必須（既存環境との衝突回避）

## 設計原則

- すべて opt-in: 利用者が必要な機能だけ enable できる
- 既存リソースは `data` source で参照のみ、`resource` で管理しない
- inline policy は機能別 JSON ファイル（`policies/*.json`）に分割
