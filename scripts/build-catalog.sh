#!/usr/bin/env bash
# documents/ と playbooks/ 配下の metadata.yaml から catalog.json を生成
#
# Usage:
#   ./scripts/build-catalog.sh [--check]
#
# --check: 既存 catalog.json と比較し、差分があれば終了コード 1（CI 用）

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$REPO_ROOT/catalog.json"
CHECK_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_MODE=1; shift ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 が必要です" >&2
  exit 1
fi

# PyYAML が必要
if ! python3 -c "import yaml" 2>/dev/null; then
  echo "PyYAML が必要です: pip install pyyaml" >&2
  exit 1
fi

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

python3 - <<PYEOF > "$TMP"
import json
import os
import sys
from pathlib import Path

import yaml

repo_root = Path("$REPO_ROOT")

ssm_documents = []
aws_playbooks = []

# SSM Documents
docs_root = repo_root / "documents" / "readonly" / "claude-investigate"
if docs_root.exists():
    for meta_path in sorted(docs_root.rglob("metadata.yaml")):
        with meta_path.open() as f:
            meta = yaml.safe_load(f)
        rel = meta_path.parent.relative_to(repo_root)
        entry = {
            "name": meta.get("name"),
            "path": str(rel),
            "category": meta.get("category"),
            "subcategory": meta.get("subcategory"),
            "safety": meta.get("safety"),
            "description": (meta.get("description") or "").strip(),
            "supported_os": meta.get("supported_os", []),
            "parameters": meta.get("parameters", []),
            "estimated_runtime_seconds": meta.get("estimated_runtime_seconds"),
        }
        ssm_documents.append(entry)

# AWS Playbooks
playbooks_root = repo_root / "playbooks" / "readonly"
if playbooks_root.exists():
    for meta_path in sorted(playbooks_root.rglob("metadata.yaml")):
        with meta_path.open() as f:
            meta = yaml.safe_load(f)
        rel = meta_path.parent.relative_to(repo_root)
        entry = {
            "name": meta.get("name"),
            "path": str(rel),
            "category": meta.get("category"),
            "subcategory": meta.get("subcategory"),
            "safety": meta.get("safety"),
            "description": (meta.get("description") or "").strip(),
            "required_permissions": meta.get("required_permissions", []),
            "parameters": meta.get("parameters", []),
            "estimated_runtime_seconds": meta.get("estimated_runtime_seconds"),
            "estimated_cost_usd": meta.get("estimated_cost_usd"),
        }
        aws_playbooks.append(entry)

catalog = {
    "version": "0.1.0",
    "generator": "scripts/build-catalog.sh",
    "investigation_methods": {
        "ssm_documents": ssm_documents,
        "aws_playbooks": aws_playbooks,
    },
}

print(json.dumps(catalog, indent=2, ensure_ascii=False))
PYEOF

if [[ "$CHECK_MODE" -eq 1 ]]; then
  if ! diff -u "$CATALOG" "$TMP" >/dev/null 2>&1; then
    echo "catalog.json が古くなっています。./scripts/build-catalog.sh を実行してください" >&2
    diff -u "$CATALOG" "$TMP" >&2 || true
    exit 1
  fi
  echo "[OK] catalog.json は最新です"
else
  mv "$TMP" "$CATALOG"
  echo "[OK] $CATALOG を更新しました"
fi
