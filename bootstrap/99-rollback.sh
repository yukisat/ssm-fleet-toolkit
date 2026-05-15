#!/usr/bin/env bash
# ssm-fleet-toolkit が作成したリソースの一括削除
#
# 削除対象は以下のプレフィックスを持つリソースのみ:
#   - SSM Document: claude-investigate-*
#   - IAM Role/Policy: ssm-fleet-*
#   - CloudFormation StackSet: ssm-fleet-*
#   - S3 Bucket: *-ssm-fleet-tf-state*
#   - DynamoDB Table: ssm-fleet-tf-lock*
#   - SSO Permission Set: ClaudeInvestigator (指定名)
#
# 既存リソース（プレフィックス不一致）には一切触れない。
#
# Usage:
#   ./99-rollback.sh [--profile <profile>] [--yes]
#
# --yes を付けない場合は対話的に確認を求める

set -euo pipefail

PROFILE="${AWS_PROFILE:-default}"
ASSUME_YES=0
PERMISSION_SET_NAME="${PERMISSION_SET_NAME:-ClaudeInvestigator}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --permission-set-name) PERMISSION_SET_NAME="$2"; shift 2 ;;
    --yes) ASSUME_YES=1; shift ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

confirm() {
  if [[ "$ASSUME_YES" -eq 1 ]]; then return 0; fi
  read -r -p "$1 [y/N]: " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

echo "ssm-fleet-toolkit ロールバック"
echo
echo "削除対象を列挙します（実際の削除前に確認します）"
echo

# まず Terraform で管理されているリソースを destroy するのが正規ルート
echo "推奨: まず deployments/<org>/ で terraform destroy を実行してください"
echo "本スクリプトは Terraform 外で残ったリソースを手動削除する用途です"
echo

if ! confirm "続行しますか？"; then
  echo "中止しました"
  exit 0
fi

# SSM Document
echo "== SSM Document =="
docs=$(aws ssm list-documents --profile "$PROFILE" \
  --filters Key=Name,Values=claude-investigate \
  --query 'DocumentIdentifiers[].Name' --output text 2>/dev/null || true)
if [[ -n "$docs" ]]; then
  echo "削除候補:"
  echo "$docs" | tr '\t' '\n' | sed 's/^/  /'
  if confirm "上記 SSM Document を削除しますか？"; then
    for d in $docs; do
      echo "delete: $d"
      aws ssm delete-document --name "$d" --profile "$PROFILE" || true
    done
  fi
else
  echo "対象なし"
fi

# DynamoDB
echo "== DynamoDB Table =="
tables=$(aws dynamodb list-tables --profile "$PROFILE" \
  --query 'TableNames[?starts_with(@, `ssm-fleet-tf-lock`)]' --output text 2>/dev/null || true)
if [[ -n "$tables" ]]; then
  echo "削除候補: $tables"
  if confirm "上記 DynamoDB テーブルを削除しますか？"; then
    for t in $tables; do
      echo "delete: $t"
      aws dynamodb delete-table --table-name "$t" --profile "$PROFILE" || true
    done
  fi
else
  echo "対象なし"
fi

# S3
echo "== S3 Bucket =="
buckets=$(aws s3api list-buckets --profile "$PROFILE" \
  --query 'Buckets[?contains(Name, `ssm-fleet-tf-state`)].Name' --output text 2>/dev/null || true)
if [[ -n "$buckets" ]]; then
  echo "削除候補: $buckets"
  echo "（state バケットは中身を確認してから削除を推奨）"
  if confirm "上記 S3 バケットを削除しますか？（中身も含めて完全削除）"; then
    for b in $buckets; do
      echo "delete bucket and contents: $b"
      aws s3 rb "s3://$b" --force --profile "$PROFILE" || true
    done
  fi
else
  echo "対象なし"
fi

echo
echo "ロールバック処理完了。"
echo "permission set / IAM ロール / StackSet は terraform destroy での削除を推奨。"
