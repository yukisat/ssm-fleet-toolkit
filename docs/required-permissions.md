# 必要な AWS 権限

このツールが必要とする AWS 権限を完全に開示します。

## 概要

権限は 3 種類に分かれます:

| 種別 | 用途 | 使用期間 | 削除可能か |
|---|---|---|---|
| インストーラ権限 | セットアップ時のみ | 1 回（セットアップ時） | ✅ 完了後に削除推奨 |
| オペレータ権限（SSM） | 日常運用の Document 実行 | 恒久 | 不可（運用必須） |
| オペレータ権限（AWS 環境調査） | Athena・CloudWatch 等 | 恒久（任意） | 機能 opt-in |

## 1. インストーラ権限（セットアップ時のみ・使い捨て可能）

委任管理アカウントの IAM ユーザーまたはロールに付与。
完全な JSON: `bootstrap/installer-policy.json`

### 主な内訳

| Sid | アクション | 用途 | リソース |
|---|---|---|---|
| OrganizationsReadAndEnableTrustedAccess | DescribeOrganization, ListAccounts, EnableAWSServiceAccess 等 | StackSets trusted access 有効化、共有先取得 | `*` |
| SSOAdminManagePermissionSets | sso, identitystore, sso-directory の管理系 | Permission Set 作成・割り当て | `*` |
| CloudFormationStackSets | StackSet の作成・更新・削除 | IAM ロール子アカウント配布 | `ssm-fleet-*` |
| IAMManageSsmFleetRoles | IAM ロール・ポリシーの作成・更新 | StackSet 用 IAM 等 | `ssm-fleet-*` |
| S3TerraformBackend | S3 バケット作成・操作 | Terraform state 用 | `*-ssm-fleet-tf-state*` |
| DynamoDBTerraformLock | DynamoDB テーブル作成 | Terraform lock 用 | `ssm-fleet-tf-lock*` |
| SSMDocumentManagement | CreateDocument, ModifyDocumentPermission 等 | Document 登録・共有 | `claude-investigate-*` |

### スコープ絞り込み

可能な限り Resource を絞っています。`*` 指定は AWS API が ARN を受け付けない（または高コスト）操作のみ:

- Organizations 系（API 仕様上 ARN を受け付けない）
- SSO Admin 系（インスタンス ARN ベースで運用、リソースレベル制限が一部のみ対応）
- Glue / Athena の参照系（DataCatalog 単位の制御が複雑）

### 推奨運用

1. インストーラ専用 IAM ユーザーまたは Permission Set を作成
2. このポリシーをアタッチ
3. セットアップ完了後にユーザー削除 or アクセスキー無効化
4. 以降のメンテナンスは通常の管理者権限で実施

## 2. オペレータ権限・SSM Document 実行（恒久・必須）

Claude や運用者が日常的に使う最小権限。
完全な JSON: `modules/sso-permission-set/policies/claude-investigator-ssm.json`

### 内訳

| Sid | アクション | リソース |
|---|---|---|
| SSMRunInvestigateDocuments | ssm:SendCommand | `arn:aws:ssm:*:*:document/claude-investigate-*`, `arn:aws:ec2:*:*:instance/*` |
| SSMReadInvocations | ssm:GetCommandInvocation, ListCommandInvocations, ListCommands, DescribeInstanceInformation, GetDocument, DescribeDocument | `*` |

### スコープ

- **書き込み権限なし**: 状態を変更しません
- **対象 Document 限定**: `claude-investigate-*` 以外は実行できません
- **EC2 instance 全般**: SendCommand のターゲットとして指定可能なインスタンス全般（IAM 側で絞り込み困難）

## 3. オペレータ権限・AWS 環境調査（恒久・opt-in）

CloudFront ログ解析、CloudWatch メトリクス取得等。利用者の判断で機能ごとに有効化。

### Athena（CloudFront ログ等の解析）

完全な JSON: `modules/sso-permission-set/policies/claude-investigator-athena.json`

| Sid | アクション | リソース |
|---|---|---|
| AthenaQueryExecution | StartQueryExecution, StopQueryExecution, GetQueryExecution, GetQueryResults 等 | `*` |
| AthenaResultsBucket | s3:PutObject, GetObject, ListBucket 等 | `*-athena-query-results*` |
| GlueCatalogForAthena | glue:GetTable, GetDatabase, GetPartitions 等 | `*` |

### CloudWatch（メトリクス・ログ）

完全な JSON: `modules/sso-permission-set/policies/claude-investigator-cloudwatch.json`

| Sid | アクション |
|---|---|
| CloudWatchMetricsRead | GetMetricData, GetMetricStatistics, ListMetrics, DescribeAlarms |
| CloudWatchLogsRead | DescribeLogGroups, FilterLogEvents, StartQuery, GetQueryResults |

## 4. 子アカウント側の権限（StackSet 経由で自動配布）

StackSet で各子アカウントに以下が配布されます:

| ロール名 | 信頼ポリシー | 権限 |
|---|---|---|
| ssm-fleet-investigate-role | 委任管理アカウント | SSM Document 実行 |

→ 子アカウントの管理者が手動で何かする必要はありません。

## 確認手順

1. `bootstrap/installer-policy.json` を目視確認
2. `bootstrap/00-check-prerequisites.sh` で現在の権限状態を確認（読み取りのみ）
3. AWS Console の IAM Access Analyzer で実際に必要な権限を絞り込み（推奨）
