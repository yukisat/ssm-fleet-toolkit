#!/usr/bin/env bash
# deployments/<org>/ をテンプレートから生成
#
# 副作用: ローカルファイル作成のみ。AWS には触らない
#
# Usage:
#   ./03-init-deployment.sh --type <single-account|multi-account-org|multi-account-manual> --name <org-name>

set -euo pipefail

TYPE=""
NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) TYPE="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

if [[ -z "$TYPE" || -z "$NAME" ]]; then
  echo "Usage: $0 --type <single-account|multi-account-org|multi-account-manual> --name <org-name>"
  exit 1
fi

case "$TYPE" in
  single-account|multi-account-org|multi-account-manual) ;;
  *) echo "Invalid type: $TYPE"; exit 1 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/deployments/_templates/$TYPE"
DEST="$REPO_ROOT/deployments/$NAME"

if [[ ! -d "$SRC" ]]; then
  echo "テンプレートが見つかりません: $SRC"
  exit 1
fi

if [[ -d "$DEST" ]]; then
  echo "既に存在します: $DEST"
  echo "上書きしません。手動で削除またはマージしてください。"
  exit 1
fi

echo "$SRC → $DEST にコピーします"
cp -R "$SRC" "$DEST"

# tfvars.example を tfvars にコピー（編集を促す）
if [[ -f "$DEST/terraform.tfvars.example" ]]; then
  cp "$DEST/terraform.tfvars.example" "$DEST/terraform.tfvars"
  echo "[INFO] terraform.tfvars を生成しました。編集して実値を入れてください"
fi

echo
echo "次のステップ:"
echo "  1. cd $DEST"
echo "  2. terraform.tfvars を編集"
echo "  3. main.tf の backend ブロックをコメント解除して bucket/key を設定"
echo "  4. terraform init"
echo "  5. terraform plan  (0 to change, 0 to destroy を確認)"
echo "  6. terraform apply"
