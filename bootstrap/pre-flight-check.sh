#!/usr/bin/env bash
# 既存リソースとの衝突チェック（読み取りのみ）
#
# 検出対象:
#   - 同名の SSO permission set
#   - 同名の SSM Document
#   - 同名の S3 バケット
#   - 同名の DynamoDB テーブル
#   （IAM ロールの衝突は StackSet デプロイ先アカウントで発生するため本 bootstrap の責務外）
#
# 衝突があれば終了コード 1 で終了

set -euo pipefail

# shellcheck disable=SC1091  # _lib.sh は同階層、CI では -x 無しで実行されるため info を抑止
source "$(dirname "$0")/_lib.sh"
audit_setup "$@"

PROFILE="${AWS_PROFILE:-default}"
PERMISSION_SET_NAME="${PERMISSION_SET_NAME:-ClaudeInvestigator}"
TF_STATE_BUCKET_PREFIX="${TF_STATE_BUCKET_PREFIX:-}"  # 呼び出し側から指定
DYNAMODB_TABLE="${DYNAMODB_TABLE:-ssm-fleet-tf-lock}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --permission-set-name) PERMISSION_SET_NAME="$2"; shift 2 ;;
    --tf-state-bucket-prefix) TF_STATE_BUCKET_PREFIX="$2"; shift 2 ;;
    --dynamodb-table) DYNAMODB_TABLE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

conflict=0
report() { echo "  $*"; }
conflict_found() { echo "  [CONFLICT] $*" >&2; conflict=1; }

echo "== SSO Permission Set: $PERMISSION_SET_NAME =="
if instance_arn=$(aws sso-admin list-instances --profile "$PROFILE" --query 'Instances[0].InstanceArn' --output text 2>/dev/null); then
  if [[ "$instance_arn" != "None" && -n "$instance_arn" ]]; then
    existing=$(aws sso-admin list-permission-sets --instance-arn "$instance_arn" --profile "$PROFILE" \
      --query 'PermissionSets' --output text 2>/dev/null | tr '\t' '\n' | while read -r psarn; do
        aws sso-admin describe-permission-set --instance-arn "$instance_arn" --permission-set-arn "$psarn" \
          --profile "$PROFILE" --query 'PermissionSet.Name' --output text 2>/dev/null
      done | grep -E "^${PERMISSION_SET_NAME}$" || true)
    if [[ -n "$existing" ]]; then
      conflict_found "同名 permission set が既に存在: $PERMISSION_SET_NAME"
    else
      report "[OK] 衝突なし"
    fi
  else
    report "[SKIP] SSO インスタンス未検出"
  fi
else
  report "[SKIP] SSO 確認に失敗（権限不足の可能性）"
fi

echo "== SSM Document (claude-investigate-*) =="
existing=$(aws ssm list-documents --profile "$PROFILE" \
  --filters Key=Name,Values=claude-investigate \
  --query 'DocumentIdentifiers[].Name' --output text 2>/dev/null || true)
if [[ -n "$existing" ]]; then
  report "[INFO] 既存の claude-investigate-* Document:"
  echo "$existing" | tr '\t' '\n' | sed 's/^/         /'
  report "→ Terraform 管理外なら手動削除または import を検討"
else
  report "[OK] 衝突なし"
fi

echo "== DynamoDB Table: $DYNAMODB_TABLE =="
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --profile "$PROFILE" >/dev/null 2>&1; then
  conflict_found "同名 DynamoDB テーブルが既に存在: $DYNAMODB_TABLE"
else
  report "[OK] 衝突なし"
fi

if [[ -n "$TF_STATE_BUCKET_PREFIX" ]]; then
  echo "== S3 Bucket: ${TF_STATE_BUCKET_PREFIX}* =="
  buckets=$(aws s3api list-buckets --profile "$PROFILE" \
    --query "Buckets[?starts_with(Name, \`${TF_STATE_BUCKET_PREFIX}\`)].Name" --output text 2>/dev/null || true)
  if [[ -n "$buckets" ]]; then
    report "[INFO] 既存バケット: $buckets"
    report "→ 既存を再利用するか別 prefix を使用するかを判断"
  else
    report "[OK] 衝突なし"
  fi
fi

echo
if [[ "$conflict" -eq 1 ]]; then
  echo "衝突が検出されました。中止します。"
  exit 1
else
  echo "衝突なし。セットアップを進められます。"
fi
