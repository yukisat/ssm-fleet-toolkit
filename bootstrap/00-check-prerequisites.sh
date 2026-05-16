#!/usr/bin/env bash
# 前提条件チェック（読み取りのみ、副作用なし）
#
# 確認項目:
#   - AWS CLI がインストール済み
#   - SSO ログイン済み（または有効な認証情報）
#   - AWS Organizations の状態
#   - StackSets trusted access の状態
#
# Usage:
#   ./00-check-prerequisites.sh [--profile <profile>]

set -euo pipefail

PROFILE="${AWS_PROFILE:-default}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

ok()   { echo "  [OK] $*"; }
warn() { echo "  [WARN] $*" >&2; }
ng()   { echo "  [NG] $*" >&2; }

echo "== AWS CLI の確認 =="
if command -v aws >/dev/null 2>&1; then
  ok "AWS CLI: $(aws --version 2>&1 | head -1)"
else
  ng "AWS CLI が見つかりません"
  exit 1
fi

echo "== 認証状態の確認 =="
if identity=$(aws sts get-caller-identity --profile "$PROFILE" --output json 2>/dev/null); then
  account=$(echo "$identity" | python3 -c "import sys,json; print(json.load(sys.stdin)['Account'])")
  arn=$(echo "$identity" | python3 -c "import sys,json; print(json.load(sys.stdin)['Arn'])")
  ok "アカウント: $account"
  ok "プリンシパル: $arn"
else
  ng "認証に失敗。SSO 未ログインの可能性: aws sso login --profile $PROFILE"
  exit 1
fi

echo "== AWS Organizations の状態 =="
if org=$(aws organizations describe-organization --profile "$PROFILE" --output json 2>/dev/null); then
  feature_set=$(echo "$org" | python3 -c "import sys,json; print(json.load(sys.stdin)['Organization']['FeatureSet'])")
  master_id=$(echo "$org" | python3 -c "import sys,json; print(json.load(sys.stdin)['Organization']['MasterAccountId'])")
  ok "Organizations 検出: master=$master_id"
  if [[ "$feature_set" == "ALL" ]]; then
    ok "FeatureSet: ALL"
  else
    warn "FeatureSet: $feature_set（StackSets 利用には ALL が必要）"
  fi
else
  ng "Organizations が未利用または権限不足。本ツールは Organizations + SSO 統合環境専用です"
  exit 1
fi

echo "== StackSets trusted access =="
if services=$(aws organizations list-aws-service-access-for-organization --profile "$PROFILE" --output json 2>/dev/null); then
  if echo "$services" | grep -q "member.org.stacksets.cloudformation.amazonaws.com"; then
    ok "trusted access: 有効"
  else
    warn "trusted access: 未有効（./01-enable-stacksets-trusted.sh で有効化）"
  fi
else
  warn "確認不可（Organizations 未利用か権限不足）"
fi

echo
echo "前提確認完了。"
