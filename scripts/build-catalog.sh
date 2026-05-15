#!/usr/bin/env bash
# documents/ と playbooks/ 配下の metadata.yaml から catalog.json を生成
#
# Usage:
#   ./scripts/build-catalog.sh [--check]
#
# --check: 既存 catalog.json と比較し、差分があれば終了コード 1（CI 用）
#
# PyYAML があれば使用、なければ簡易パーサにフォールバック。
# 簡易パーサは flat なキー: 値 と list (- item) のみ対応。
# 入れ子 dict/list は full YAML parser が必要。

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

TMP=$(mktemp "${TMPDIR:-/tmp}/ssm-fleet-catalog.XXXXXX")
trap 'rm -f "$TMP"' EXIT

python3 - <<'PYEOF' > "$TMP"
import json
import os
import re
import sys
from pathlib import Path

repo_root = Path(os.environ.get("REPO_ROOT", "."))

# PyYAML があれば使う、なければ簡易パーサで対応
try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False


def parse_simple_yaml(text):
    """簡易 YAML パーサ。flat key:value、リスト、複数行文字列 (|, >) に対応。
    入れ子の dict/list には対応しないので、metadata.yaml の構造に依存する。
    """
    result = {}
    lines = text.splitlines()
    i = 0
    current_key = None
    current_list = None
    block_lines = None
    block_indent = None
    block_mode = None  # '|' or '>'

    while i < len(lines):
        raw = lines[i]
        line = raw.rstrip()
        # ブロックスカラー処理
        if block_lines is not None:
            stripped = raw[block_indent:] if len(raw) >= block_indent else raw.strip()
            if raw.strip() == "":
                block_lines.append("")
                i += 1
                continue
            actual_indent = len(raw) - len(raw.lstrip())
            if actual_indent < block_indent:
                # ブロック終了
                joined = "\n".join(block_lines).rstrip() if block_mode == "|" else " ".join(b.strip() for b in block_lines if b.strip())
                result[current_key] = joined
                block_lines = None
                block_indent = None
                continue
            else:
                block_lines.append(raw[block_indent:] if block_mode == "|" else raw.strip())
                i += 1
                continue
        if line.strip() == "" or line.lstrip().startswith("#"):
            i += 1
            continue
        # トップレベルキー
        m = re.match(r"^([a-zA-Z_][a-zA-Z0-9_]*):\s*(.*)$", line)
        if m:
            key = m.group(1)
            val = m.group(2).strip()
            if val in ("|", "|-", ">"):
                current_key = key
                # 次の行のインデントを判定
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    block_indent = len(next_line) - len(next_line.lstrip())
                block_lines = []
                block_mode = "|" if val.startswith("|") else ">"
                i += 1
                continue
            if val == "":
                # リストか入れ子か後続行で判定
                # 次の非空行を見る
                j = i + 1
                while j < len(lines) and (lines[j].strip() == "" or lines[j].lstrip().startswith("#")):
                    j += 1
                if j < len(lines):
                    nxt = lines[j]
                    if nxt.lstrip().startswith("- "):
                        # リスト処理
                        items = []
                        k = j
                        list_indent = len(nxt) - len(nxt.lstrip())
                        while k < len(lines):
                            ln = lines[k]
                            if ln.strip() == "":
                                k += 1
                                continue
                            cur_indent = len(ln) - len(ln.lstrip())
                            if cur_indent < list_indent:
                                break
                            stripped = ln.strip()
                            if stripped.startswith("- "):
                                item_val = stripped[2:].strip()
                                # ": "（コロン + スペース）があれば key:value、それ以外（例 ssm:Foo）はスカラ
                                if ": " in item_val or item_val.endswith(":"):
                                    # オブジェクトリスト要素の最初のフィールド
                                    obj = {}
                                    fk, _, fv = item_val.partition(":")
                                    obj[fk.strip()] = parse_scalar(fv.strip())
                                    # 続くフィールドを取り込み
                                    k += 1
                                    while k < len(lines):
                                        ln2 = lines[k]
                                        if ln2.strip() == "":
                                            k += 1
                                            continue
                                        cur2 = len(ln2) - len(ln2.lstrip())
                                        if cur2 <= list_indent:
                                            break
                                        s2 = ln2.strip()
                                        if s2.startswith("- "):
                                            break
                                        if ": " in s2:
                                            fk2, _, fv2 = s2.partition(":")
                                            obj[fk2.strip()] = parse_scalar(fv2.strip())
                                        k += 1
                                    items.append(obj)
                                    continue
                                else:
                                    items.append(parse_scalar(item_val))
                            k += 1
                        result[key] = items
                        i = k
                        continue
                # 入れ子オブジェクトはスキップ（未対応）
                result[key] = None
                i += 1
                continue
            result[key] = parse_scalar(val)
            i += 1
            continue
        i += 1
    # 未処理ブロック
    if block_lines is not None:
        joined = "\n".join(block_lines).rstrip() if block_mode == "|" else " ".join(b.strip() for b in block_lines if b.strip())
        result[current_key] = joined
    return result


def strip_inline_comment(val):
    """インラインコメント `... # comment` を除去（引用符内は保持）"""
    in_single = False
    in_double = False
    for i, c in enumerate(val):
        if c == "'" and not in_double:
            in_single = not in_single
        elif c == '"' and not in_single:
            in_double = not in_double
        elif c == "#" and not in_single and not in_double:
            # # の前に空白があるか確認（リテラルの一部かどうか）
            if i == 0 or val[i - 1].isspace():
                return val[:i].rstrip()
    return val


def parse_scalar(val):
    val = strip_inline_comment(val)
    # インラインリスト [a, b, c]
    if val.startswith("[") and val.endswith("]"):
        inner = val[1:-1].strip()
        if not inner:
            return []
        return [parse_scalar(p.strip()) for p in inner.split(",")]
    if val.startswith('"') and val.endswith('"'):
        return val[1:-1]
    if val.startswith("'") and val.endswith("'"):
        return val[1:-1]
    if val in ("null", "~", ""):
        return None
    if val in ("true", "True"):
        return True
    if val in ("false", "False"):
        return False
    try:
        if "." in val:
            return float(val)
        return int(val)
    except ValueError:
        return val


def load_metadata(path):
    text = path.read_text(encoding="utf-8")
    if HAS_YAML:
        return yaml.safe_load(text)
    return parse_simple_yaml(text)


ssm_documents = []
aws_playbooks = []

docs_root = repo_root / "documents" / "readonly" / "claude-investigate"
if docs_root.exists():
    for meta_path in sorted(docs_root.rglob("metadata.yaml")):
        meta = load_metadata(meta_path)
        rel = meta_path.parent.relative_to(repo_root)
        entry = {
            "name": meta.get("name"),
            "path": str(rel),
            "category": meta.get("category"),
            "subcategory": meta.get("subcategory"),
            "safety": meta.get("safety"),
            "description": (meta.get("description") or "").strip(),
            "supported_os": meta.get("supported_os") or [],
            "parameters": meta.get("parameters") or [],
            "estimated_runtime_seconds": meta.get("estimated_runtime_seconds"),
        }
        ssm_documents.append(entry)

playbooks_root = repo_root / "playbooks" / "readonly"
if playbooks_root.exists():
    for meta_path in sorted(playbooks_root.rglob("metadata.yaml")):
        meta = load_metadata(meta_path)
        rel = meta_path.parent.relative_to(repo_root)
        entry = {
            "name": meta.get("name"),
            "path": str(rel),
            "category": meta.get("category"),
            "subcategory": meta.get("subcategory"),
            "safety": meta.get("safety"),
            "description": (meta.get("description") or "").strip(),
            "required_permissions": meta.get("required_permissions") or [],
            "parameters": meta.get("parameters") or [],
            "estimated_runtime_seconds": meta.get("estimated_runtime_seconds"),
            "estimated_cost_usd": meta.get("estimated_cost_usd"),
        }
        aws_playbooks.append(entry)

catalog = {
    "version": "0.3.0",
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
