# 監査ログ運用

セットアップスキル・運用スキルが実行するすべてのアクションを、利用者が後から検証できる仕組みを提供します。

## ログファイル

- `deployments/<org>/install-audit.log`: セットアップスキルによる導入時の全アクション
- `deployments/<org>/operation-audit.log`: 運用時の調査アクション（オプション）

これらのファイルは `.gitignore` 対象（実値が含まれるため）。バックアップは利用者の責任で。

## 記録されるイベント

| イベント種別 | タグ | 内容 |
|---|---|---|
| ユーザー承認 | `[USER]` | 「進めて」「中止」等の承認・拒否 |
| スクリプト実行 | `[EXEC]` | bootstrap/ スクリプトの実行開始 |
| スクリプト結果 | `[RESULT]` | 成功・失敗・スキップ |
| AWS API 呼び出し | `[AWS]` | API 名と結果 |
| Terraform plan | `[TF_PLAN]` | 変更サマリ（add/change/destroy 数） |
| Terraform apply | `[TF_APPLY]` | apply 開始と結果 |
| エラー | `[ERROR]` | 例外発生時の詳細 |

## ログ形式

```
2026-05-16T01:30:00Z [INFO] Setup started by Claude Code session abc123
2026-05-16T01:30:15Z [USER] User approved Phase 0 (preview)
2026-05-16T01:31:00Z [EXEC] bootstrap/00-check-prerequisites.sh --profile org-admin
2026-05-16T01:31:02Z [RESULT] OK: AWS CLI version 2.27.0
2026-05-16T01:31:02Z [RESULT] OK: SSO logged in
2026-05-16T01:31:02Z [RESULT] NG: StackSets trusted access not enabled
2026-05-16T01:31:30Z [USER] User approved enabling StackSets trusted access
2026-05-16T01:31:35Z [EXEC] bootstrap/01-enable-stacksets-trusted.sh
2026-05-16T01:31:38Z [AWS] organizations:EnableAWSServiceAccess succeeded
2026-05-16T01:35:00Z [TF_PLAN] Plan: 20 to add, 0 to change, 0 to destroy
2026-05-16T01:35:15Z [USER] User approved terraform apply
2026-05-16T01:36:30Z [TF_APPLY] Apply complete: 20 resources created
```

## ログを使ったトラブルシューティング

### 「何が作られたか確認したい」

```bash
grep -E '^\[TF_APPLY\]|created' install-audit.log
```

### 「失敗時の状況確認」

```bash
grep -E '^\[ERROR\]|^\[RESULT\] NG' install-audit.log
```

### 「特定の AWS 操作の有無確認」

```bash
grep '\[AWS\]' install-audit.log | grep -i 'organizations'
```

## 監査の長期保存

長期保管が必要な場合（コンプライアンス要件等）:

- 利用者の S3 バケットにアップロード（手動）
- 組織の SIEM に転送（手動またはアラート設定）
- このリポジトリにはコミットしない（実値が含まれるため）

## CloudTrail との関係

このローカルログとは別に、AWS 側では CloudTrail に**通常通り記録される**:

- すべての AWS API 呼び出しが CloudTrail に残る
- IP アドレス、principal、操作内容が記録される
- 既存の監査基盤がそのまま使える

ローカルログは「Claude Code が何をしたか」の視点、CloudTrail は「AWS 側で何が起きたか」の視点。両方で相互検証可能。
