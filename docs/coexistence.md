# 既存環境との共存

このツールは既存の AWS 環境に**後から差し込む**ことを前提に設計されています。
このページは「既存環境を壊さない」という保証の根拠を説明します。

## 保証すること

- 既存の SSO permission set には一切触れません
- 既存の IAM ロール・ポリシーには一切触れません
- 既存の S3 バケット・DynamoDB テーブルには一切触れません
- 既存の SSM Document（`claude-investigate-*` 以外）には一切触れません
- 既存の CloudFormation スタック・StackSet には一切触れません

## 仕組み

### 1. 命名プレフィックス

作成するリソースはすべて以下のプレフィックスを持ちます:

| リソース種別 | プレフィックス |
|---|---|
| Permission Set | `ClaudeInvestigator`（変更可） |
| IAM Role / Policy | `ssm-fleet-*` |
| S3 Bucket | `<account>-ssm-fleet-tf-state*` |
| DynamoDB Table | `ssm-fleet-tf-lock*` |
| SSM Document | `claude-investigate-*` |
| CloudFormation StackSet | `ssm-fleet-*` |

### 2. Terraform state の物理分離

専用バケット（`<account>-ssm-fleet-tf-state`）に独立保管。
他の Terraform プロジェクトの state とは混ざりません。

### 3. data source による既存リソース参照

SSO インスタンス、Organizations、既存グループ等は `data` source で参照のみ。
管理対象（`resource` 宣言）には含めません。

### 4. terraform plan の差分提示

apply 前に必ず `terraform plan` を実行し、利用者に提示します。
**`0 to change, 0 to destroy` を必ず確認**してください。
追加（`+ resource ... will be created`）以外が出る場合は要調査。

## 衝突チェック

セットアップスキルは apply 前に `bootstrap/pre-flight-check.sh` を実行し、以下を検出:

- 同名の SSO permission set
- 同名の DynamoDB テーブル
- 既存の `claude-investigate-*` Document（別 Terraform で管理されている可能性）
- 同 prefix の S3 バケット

衝突があれば中止し、利用者と対応方針を相談。

## いつでも撤退できる

### 推奨ルート（クリーン）

```bash
cd deployments/<org>/
terraform destroy
```

すべての作成リソースが Terraform 管理下のため、destroy で完全に元に戻ります。

### 緊急ルート（Terraform state を失った場合等）

```bash
./bootstrap/99-rollback.sh
```

`ssm-fleet-*` / `claude-investigate-*` プレフィックスのリソースを手動削除します。
**プレフィックス不一致のリソースには触れません。**

## 既存環境への影響範囲（明示）

このツールが既存環境に与える「正規の変更」は以下の 1 点のみ:

- **AWS Organizations の StackSets trusted access 有効化**（組織レベル設定）
  - これは AWS 公式機能の有効化であり、既存リソースには影響しません
  - 既に有効化済みの場合は何もしません
  - `aws organizations disable-aws-service-access` で無効化可能（ただし他のツールも影響を受ける可能性あり）

## 起こり得る摩擦（隠さず開示）

| 摩擦 | 説明 | 緩和 |
|---|---|---|
| SCP（Service Control Policy） | 組織で SCP がかかっていると一部操作が拒否される | エラーを Claude が読み、SCP の可能性を指摘 |
| inline policy サイズ上限 | permission set の inline policy は 10KB 上限 | 機能ごとに分割、必要な機能だけ合成 |
| StackSet concurrent operations | 既に別 StackSet 操作が走っているとブロック | スクリプト内でリトライ |
| 既存の `claude-investigate-*` Document | 別 Terraform で管理されている可能性 | pre-flight-check で検出、import か別 prefix で対応 |
| Organizations 委任管理者の制約 | 委任管理アカウントから組織全体への操作には制限あり | エラー時は管理アカウントから実行を提案 |

## 確認手順（導入担当者向け）

1. `docs/required-permissions.md` で必要 IAM 権限を確認
2. `bootstrap/installer-policy.json` の中身を目視確認
3. `bootstrap/00-check-prerequisites.sh` をローカルで実行（読み取りのみ）
4. `bootstrap/pre-flight-check.sh` で衝突がないことを確認
5. セットアップスキル経由で実行（plan mode で全工程確認後に承認）
6. 各 terraform plan で `0 to change, 0 to destroy` を確認
