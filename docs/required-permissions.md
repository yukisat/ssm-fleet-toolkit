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
| OrganizationsReadAndEnableTrustedAccess | DescribeOrganization, ListAccounts, ListRoots, EnableAWSServiceAccess 等 | StackSets trusted access 有効化、共有先取得、ルート OU 参照 | `*` |
| SSOAdminManagePermissionSets | sso:* の個別アクション 23 個（書き込みあり） | Permission Set 作成・割り当て・タグ管理 | `*` |
| IdentityStoreReadOnly | identitystore の List/Describe/Get 系 | グループ ID 取得（書き込みなし） | `*` |
| CloudFormationStackSets | StackSet の作成・更新・削除 | IAM ロール子アカウント配布 | `ssm-fleet-*` |
| IAMManageSsmFleetRoles | IAM ロール・ポリシーの作成・更新 | StackSet 用 IAM 等 | `ssm-fleet-*` |
| IAMForSSOProvisioning | iam:CreateRole, GetSAMLProvider 等 | SSO Account Assignment 作成時に SSO が裏で aws-reserved/sso.amazonaws.com/* ロール作成・AWSSSO_* SAML プロバイダ更新を行うため必要 | `aws-reserved/sso.amazonaws.com/*` / `saml-provider/AWSSSO_*` |
| S3TerraformBackend | S3 バケット作成・操作（Versioning 含む） | Terraform state 用。GetObjectVersion / DeleteObjectVersion / ListBucketVersions も rollback 時の versioned bucket クリーンアップで必要 | `*-ssm-fleet-tf-state*` |
| DynamoDBTerraformLock | DynamoDB テーブル作成 | Terraform lock 用 | `ssm-fleet-tf-lock*` |
| SSMDocumentManagement | CreateDocument, ModifyDocumentPermission 等 | Document 登録・共有 | `claude-investigate-*` |

### スコープ絞り込み

可能な限り Resource を絞っています。`*` 指定は AWS API が ARN を受け付けない（または高コスト）操作のみ:

- Organizations 系（API 仕様上 ARN を受け付けない）
- SSO Admin 系（インスタンス ARN ベースで運用、リソースレベル制限が一部のみ対応）
- Glue / Athena の参照系（DataCatalog 単位の制御が複雑）

### ⚠️ SSO 権限の重要な注意

`SSOAdminManagePermissionSets` の 23 アクションは Resource `*` 指定です。これは AWS Identity Center の API 仕様上、Permission Set ARN は作成時にしか分からないため事前にリソース限定できない制約によります。

**意味するリスク**:

- インストーラ権限を持つ間は、組織内の**すべての Permission Set を変更・削除可能**
- 既存の他 Permission Set（AdministratorAccess 等）への割り当ても操作可能
- 誤操作した場合「他の社員の SSO ログイン環境を破壊する」リスクあり

**緩和策**:

1. **使い捨てを徹底**: インストーラ専用 IAM ユーザー / Permission Set を作成し、セットアップ完了後に**即削除**
2. **作業ログ**: CloudTrail で SSO 操作を全件記録、想定外操作の事後検知
3. **作業者を絞る**: 信頼できる管理者 1 名がセットアップを実行
4. **本番環境では事前にステージング検証**

書き込み権限を含むアクション（参考）:

- `sso:CreatePermissionSet`, `sso:UpdatePermissionSet`, `sso:DeletePermissionSet`
- `sso:CreateAccountAssignment`, `sso:DeleteAccountAssignment`
- `sso:AttachManagedPolicyToPermissionSet`, `sso:DetachManagedPolicyFromPermissionSet`
- `sso:PutInlinePolicyToPermissionSet`, `sso:DeleteInlinePolicyFromPermissionSet`
- `sso:TagResource`, `sso:UntagResource`

`IdentityStoreReadOnly` は読み取り専用なのでリスクは限定的。

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

テンプレート: `modules/sso-permission-set/policies/claude-investigator-athena.json.tftpl`
（`athena_regions` と `athena_results_bucket_prefix` を展開して生成）

| Sid | アクション | リソース | 条件 |
|---|---|---|---|
| AthenaQueryExecution | athena:StartQueryExecution, StopQueryExecution | `*` | `aws:RequestedRegion` ∈ athena_regions |
| AthenaWorkGroupCreate | athena:CreateWorkGroup, TagResource | `workgroup/<workgroup_name>` | `aws:RequestedRegion` ∈ athena_regions |
| AthenaResultsBucketCreate | s3:CreateBucket, PutBucketPublicAccessBlock, PutEncryptionConfiguration, PutBucketTagging | `<prefix>-*` | `aws:RequestedRegion` ∈ athena_regions |
| AthenaResultsBucketUse | s3:PutObject, AbortMultipartUpload, GetObject, ListBucket, GetBucketLocation | `<prefix>-*` | — |

設計のポイント:

- **リージョン限定**: `athena_regions`（= `primary_region` + `document_regions`）以外のリージョンでは
  Athena 実行・WorkGroup 作成・結果バケット作成のいずれもできない。
- **専用バケットのみ**: 結果バケットは toolkit 専用名 `<prefix>-*`（既定 prefix = `ssm-fleet-athena-results`）
  のみ作成・利用可能。お客様環境の既存バケットは使わせない。
- **専用 WorkGroup のみ**: コスト制御（スキャン量上限）付き WorkGroup `<workgroup_name>`
  （既定 `ssm-fleet-investigator`）のみ作成可能。無い場合は調査ロール自身が作成できる。
- **作成も許可**: 結果バケット・WorkGroup が無い場合は調査ロール自身が当該リージョンに作成できる
  （いずれも専用名＋許可リージョンに限定）。
- **取得系・Glue は ReadOnlyAccess 側**: athena:Get*/List*、glue:Get*、結果以外の s3:Get*/List* は
  `attach_aws_readonly = true` の ReadOnlyAccess でカバーするため inline policy には含めない（最小化）。

結果バケットの命名規約（調査スキル／playbook 側で使用）: `<prefix>-<アカウントID>-<リージョン>`
例: `ssm-fleet-athena-results-123456789012-ap-northeast-1`

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
