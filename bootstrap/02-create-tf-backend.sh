#!/usr/bin/env bash
# Terraform backend 用の S3 バケット + DynamoDB テーブルを作成
#
# 命名規約:
#   S3 bucket:      <account-id>-ssm-fleet-tf-state
#   DynamoDB table: ssm-fleet-tf-lock
#
# 副作用: S3 バケット作成、DynamoDB テーブル作成（既存なら何もしない）
# 冪等: 既に存在する場合はスキップ
#
# Usage:
#   ./02-create-tf-backend.sh [--profile <profile>] [--region <region>] [--dry-run]

set -euo pipefail

PROFILE="${AWS_PROFILE:-default}"
REGION="${AWS_REGION:-ap-northeast-1}"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
BUCKET="${ACCOUNT_ID}-ssm-fleet-tf-state"
TABLE="ssm-fleet-tf-lock"

echo "対象アカウント: $ACCOUNT_ID"
echo "リージョン: $REGION"
echo "S3 バケット: $BUCKET"
echo "DynamoDB テーブル: $TABLE"
echo

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY-RUN] $*"
  else
    echo "[EXEC] $*"
    # shellcheck disable=SC2294
    # 引数を 1 つの文字列として受け取り eval する（呼び出し側で長い CLI 文字列を渡しているため）
    eval "$@"
  fi
}

# S3 バケット
echo "== S3 バケット =="
if aws s3api head-bucket --bucket "$BUCKET" --profile "$PROFILE" 2>/dev/null; then
  echo "[SKIP] $BUCKET は既に存在します"
else
  if [[ "$REGION" == "us-east-1" ]]; then
    run "aws s3api create-bucket --bucket '$BUCKET' --profile '$PROFILE' --region '$REGION'"
  else
    run "aws s3api create-bucket --bucket '$BUCKET' --profile '$PROFILE' --region '$REGION' --create-bucket-configuration LocationConstraint='$REGION'"
  fi

  # バージョニング有効化
  run "aws s3api put-bucket-versioning --bucket '$BUCKET' --profile '$PROFILE' --versioning-configuration Status=Enabled"

  # 暗号化有効化
  run "aws s3api put-bucket-encryption --bucket '$BUCKET' --profile '$PROFILE' --server-side-encryption-configuration '{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}'"

  # パブリックアクセス完全ブロック
  run "aws s3api put-public-access-block --bucket '$BUCKET' --profile '$PROFILE' --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  echo "[OK] バケット作成完了"
fi

# DynamoDB テーブル
echo
echo "== DynamoDB テーブル =="
if aws dynamodb describe-table --table-name "$TABLE" --profile "$PROFILE" --region "$REGION" >/dev/null 2>&1; then
  echo "[SKIP] $TABLE は既に存在します"
else
  run "aws dynamodb create-table \
    --table-name '$TABLE' \
    --profile '$PROFILE' \
    --region '$REGION' \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --tags Key=ssm-fleet:managed-by,Value=ssm-fleet-toolkit"

  if [[ "$DRY_RUN" -eq 0 ]]; then
    echo "テーブル ACTIVE 待機中..."
    aws dynamodb wait table-exists --table-name "$TABLE" --profile "$PROFILE" --region "$REGION"
  fi
  echo "[OK] テーブル作成完了"
fi

echo
echo "Terraform backend 設定:"
cat <<EOF

  backend "s3" {
    bucket         = "$BUCKET"
    key            = "ssm-fleet/<environment>/terraform.tfstate"
    region         = "$REGION"
    dynamodb_table = "$TABLE"
    encrypt        = true
  }

EOF
