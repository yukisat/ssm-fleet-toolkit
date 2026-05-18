---
name: ssm-fleet-setup
description: |
  ssm-fleet-toolkit を AWS 環境に導入する対話型セットアップスキル。
  AWS Organizations + AWS Identity Center (SSO) 統合済み環境専用。
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

### Step 1: 認証状態の検出と IAM 利用者の準備

**ここで AWS 認証を確認・準備する**。`bootstrap/` 配下のスクリプト実行に先立ち、Claude が AWS に到達できる状態を整える。

#### 1-1. 現在の認証状態を確認

```bash
aws sts get-caller-identity 2>&1
```

成功（`Account` / `Arn` が返る）した場合 → 1-2 で権限充足を確認 → Step 2 へ。
失敗（`Unable to locate credentials` 等）した場合 → 1-3 へ。

#### 1-2. 既存認証の権限充足を確認

`bootstrap/installer-policy.json` に列挙された権限が付与されているか、`AdministratorAccess` 相当か、いずれかであることを確認。
不足する権限があれば 1-3 の手順で適切な IAM ユーザーを作成し直す。

#### 1-3. インストール用 IAM ユーザー作成の案内（認証未設定 or 権限不足の場合）

利用者は通常 IAM ユーザーを事前用意していないため、root 権限を持つアカウントで以下を一度だけ実行してもらう。CloudShell（root ログイン）またはローカル PC でも可。

**ステップ A: インラインポリシー JSON を控える**

`bootstrap/installer-policy.json` の内容を利用者に提示する。これがセットアップ完了まで必要な最小権限。

**ステップ B: IAM ユーザー作成 + ポリシー付与（利用者が実行）**

`bootstrap/installer-policy.json` は約 5KB あり、IAM インラインポリシーの上限（2048 バイト）を超えるため、**customer-managed policy として作成 → ユーザーにアタッチ** する方式を使う。

```bash
# AWS CLI を使う場合（CloudShell 推奨）
aws iam create-user --user-name ssm-fleet-installer

# customer-managed policy として作成（最大 10240 バイト）
POLICY_ARN=$(aws iam create-policy \
  --policy-name ssm-fleet-installer-policy \
  --policy-document file://bootstrap/installer-policy.json \
  --query 'Policy.Arn' --output text)

# ユーザーにアタッチ
aws iam attach-user-policy \
  --user-name ssm-fleet-installer \
  --policy-arn "$POLICY_ARN"

# 確認
aws iam list-attached-user-policies --user-name ssm-fleet-installer --output table

# アクセスキー発行（出力をその場で控える、画面でしか見られない）
aws iam create-access-key --user-name ssm-fleet-installer
```

**注意**: `aws iam put-user-policy`（インラインポリシー）は 2048 バイト上限のため `installer-policy.json` には使えない。必ず `create-policy` + `attach-user-policy` を使う。

コンソール手順は `docs/manual-setup.md`（あれば）を参照。

**ステップ C: ローカルに認証を設定（利用者が実行）**

```bash
aws configure --profile ssm-fleet-installer
# AWS Access Key ID:     <ステップ B の出力>
# AWS Secret Access Key: <ステップ B の出力>
# Default region:        ap-northeast-1
# Default output:        json

# 動作確認
aws sts get-caller-identity --profile ssm-fleet-installer
```

その後、本セットアップを `AWS_PROFILE=ssm-fleet-installer` で再実行するよう案内する。

**重要な注意事項を必ず提示**:

- このユーザーは **セットアップ完了後に削除可能**。常用のものではない
- アクセスキーを `git` にコミットしない
- インラインポリシーは `bootstrap/installer-policy.json` 1 つだけ。`AdministratorAccess` の付与は推奨しない
- root のアクセスキーは絶対に作らない

#### 1-4. 認証確認後の継続

`aws sts get-caller-identity` が成功してから Step 2 に進む。

### Step 2: 前提環境の確認

このツールは AWS Organizations + AWS Identity Center (SSO) 統合済み環境のみをサポート。
利用者環境が以下を満たすか確認する:

- AWS Organizations が all-features モード
- AWS Identity Center が有効化されている
- StackSets trusted access が有効
- 委任管理アカウントが決定済み

いずれかを満たさない場合は対象外として中止し、フォークでの対応を提案する。

### Step 3: 前提条件チェック

`./bootstrap/00-check-prerequisites.sh` を実行。
不足項目があれば利用者に承認を得てから個別に修復:

- StackSets trusted access 未有効 → `01-enable-stacksets-trusted.sh`
- SSO 未ログイン → 利用者に `aws sso login` を依頼

### Step 4: 既存リソースとの衝突チェック

`./bootstrap/pre-flight-check.sh` を実行。
衝突があれば中止し、利用者と方針を相談（別名指定 or import）。

### Step 5: 委任管理アカウントの選定（Organizations の場合）

SSO で利用可能なアカウント一覧から利用者に選ばせる。
推奨基準を提示:

- セキュリティ・監査用の独立アカウント が望ましい
- アクセス頻度が低いアカウントが望ましい
- 既に管理機能を集約している場合はそちらに統合

### Step 6: Terraform backend の準備

S3 バケット + DynamoDB テーブルを委任管理アカウントに作成。
利用者の承認後、`./bootstrap/02-create-tf-backend.sh` を実行。

### Step 7: deployments/<org>/ の生成

`./bootstrap/03-init-deployment.sh --name <org>` で
`deployments/_template/` をコピーし変数を埋める。

### Step 8: Terraform 実行

各段階で `terraform plan` を提示し承認を得てから `apply`:

1. permission set 関連
2. SSM Document 登録（管理アカウント）
3. IAM ロール StackSet 配布（子アカウント）
4. Document 共有設定（permissions）

各 plan は `0 to change, 0 to destroy` であることを必ず確認・報告。

### Step 9: 動作確認

テストインスタンスに対して `claude-investigate-os-disk-usage` を実行し、
正常応答が返ることを確認。

### Step 9.5: ローカル PC の SSO プロファイル設定

調査スキル（`ssm-fleet-investigate`）を使うには、`ClaudeInvestigator` Permission Set で
ログインできる AWS プロファイルをローカルに設定する必要がある。

#### 9.5-A. 自分のユーザーを `investigators` グループに追加

`ClaudeInvestigator` Permission Set は `investigators` グループに割り当てられている。
グループにメンバーが追加されていないと、SSO ログイン時に `ClaudeInvestigator` が選択肢に表示されない。

```bash
# 自分の SSO ユーザー ID を確認
aws identitystore list-users \
  --identity-store-id <IDENTITY_STORE_ID> \
  --query 'Users[*].[UserId,UserName]' \
  --output table

# investigators グループに追加（USER_ID は上の出力から）
aws identitystore create-group-membership \
  --identity-store-id <IDENTITY_STORE_ID> \
  --group-id <INVESTIGATORS_GROUP_ID> \
  --member-id MemberId={UserId="<USER_ID>"}
```

`<IDENTITY_STORE_ID>` と `<INVESTIGATORS_GROUP_ID>` は Terraform apply の出力または
`deployments/<org>/terraform.tfvars` の設定値から確認する。

#### 9.5-B. SSO ポータル URL の確認

AWS コンソール → **IAM Identity Center** → 左メニュー「ダッシュボード」→
「AWS アクセスポータル URL」をコピーする。

#### 9.5-C. プロファイルの設定

```bash
aws configure sso --profile claude-investigator
```

対話形式で以下を入力:

| 項目 | 値 |
|---|---|
| SSO session name | `ssm-fleet`（任意） |
| SSO start URL | IAM Identity Center のアクセスポータル URL |
| SSO region | `ap-northeast-1` |
| SSO registration scopes | そのまま Enter |
| アカウント | セットアップ対象アカウントを選択 |
| Permission Set | **`ClaudeInvestigator`** |
| Default region | `ap-northeast-1` |
| Default output | `json` |

#### 9.5-D. ロール選択の確認（重要）

`aws configure sso` の実行中、Permission Set の選択肢に `ClaudeInvestigator` **以外**
（例: `AdministratorAccess`）しか表示されない場合は **9.5-A のグループ追加が完了していない**。
誤って別のロールを選択すると調査スキルが意図しない権限で動作するため、必ず確認すること。

`ClaudeInvestigator` が表示されない場合の対処:
1. 9.5-A を再確認してグループメンバーシップを確認する
2. グループへの追加後、ブラウザの SSO セッションをクリアして再試行する
3. `aws configure sso --profile claude-investigator` をやり直す

#### 9.5-E. ログインと動作確認

```bash
# ブラウザが開いて SSO 認証が完了する
aws sso login --profile claude-investigator

# 認証確認（RoleName に ClaudeInvestigator が含まれることを確認）
aws sts get-caller-identity --profile claude-investigator
```

出力の `"AssumedRoleId"` または `"Arn"` に `ClaudeInvestigator` が含まれていれば成功。
`AdministratorAccess` 等が含まれている場合はプロファイルを設定し直すこと。

**注意**: このプロファイルが `ssm-fleet-investigate` スキルの実行に使われる。
複数アカウントを調査する場合は `--profile` に異なるアカウント向けプロファイルを追加で作成すること。

### Step 10: 完了報告

- 作成されたリソース一覧
- 監査ログのパス（`install-audit.log`）
- 次にできること（`/ssm-fleet-investigate` の使い方）
- インストーラ権限の削除推奨（`ssm-fleet-installer` IAM ユーザーは Step 1 で作成したもの）。利用者に以下の削除手順を提示:

```bash
# アクセスキー削除
KEYS=$(aws iam list-access-keys --user-name ssm-fleet-installer --query 'AccessKeyMetadata[].AccessKeyId' --output text)
for k in $KEYS; do aws iam delete-access-key --user-name ssm-fleet-installer --access-key-id "$k"; done

# Managed policy デタッチ + 削除
POLICY_ARN=$(aws iam list-attached-user-policies --user-name ssm-fleet-installer --query 'AttachedPolicies[?PolicyName==`ssm-fleet-installer-policy`].PolicyArn | [0]' --output text)
aws iam detach-user-policy --user-name ssm-fleet-installer --policy-arn "$POLICY_ARN"
aws iam delete-policy --policy-arn "$POLICY_ARN"

# ユーザー削除
aws iam delete-user --user-name ssm-fleet-installer
```

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
