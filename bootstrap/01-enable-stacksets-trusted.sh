#!/usr/bin/env bash
# AWS Organizations の CloudFormation StackSets trusted access を有効化
#
# 副作用: 組織レベルで AWS service access を有効化する
# 冪等: 既に有効化されていてもエラーにならない
#
# Usage:
#   ./01-enable-stacksets-trusted.sh [--profile <profile>] [--dry-run]

set -euo pipefail

# shellcheck source=_lib.sh
source "$(dirname "$0")/_lib.sh"
audit_setup "$@"

PROFILE="${AWS_PROFILE:-default}"
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

SERVICE="member.org.stacksets.cloudformation.amazonaws.com"

echo "対象: AWS Organizations / Service: $SERVICE"

if aws organizations list-aws-service-access-for-organization --profile "$PROFILE" --output text \
    --query "EnabledServicePrincipals[?ServicePrincipal=='$SERVICE'].ServicePrincipal" | grep -q "$SERVICE"; then
  echo "[SKIP] 既に有効化済みです"
  audit_log "enable-aws-service-access" "skip" "already enabled: $SERVICE"
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[DRY-RUN] 実行されるコマンド:"
  echo "  aws organizations enable-aws-service-access --service-principal $SERVICE --profile $PROFILE"
  audit_log "enable-aws-service-access" "dry-run" "service=$SERVICE profile=$PROFILE"
  exit 0
fi

echo "実行: aws organizations enable-aws-service-access --service-principal $SERVICE"
aws organizations enable-aws-service-access \
  --service-principal "$SERVICE" \
  --profile "$PROFILE"
echo "[OK] trusted access を有効化しました"
audit_log "enable-aws-service-access" "ok" "service=$SERVICE profile=$PROFILE"
