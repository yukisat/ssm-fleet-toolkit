#!/usr/bin/env bash
# 共通ライブラリ。bootstrap/ 配下のスクリプトから source する。
#
# 提供する関数:
#   audit_log <event> <result> [details]  — install-audit.log に追記
#   audit_setup                            — script 開始時の自動セットアップ（trap 含む）

# ログファイル位置（リポジトリルート）
AUDIT_LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT_LOG_PATH="$AUDIT_LOG_DIR/install-audit.log"

# 現在のスクリプト名を取り出す（呼び出し元から設定可能）
AUDIT_SCRIPT_NAME="${AUDIT_SCRIPT_NAME:-$(basename "${BASH_SOURCE[1]:-unknown}")}"

# audit_log <event> <result> [details]
#   event:   開始 / 終了 / アクション識別子（free text、空白は _ 推奨）
#   result:  ok / fail / skip / dry-run / info
#   details: 自由記述（オプション）
audit_log() {
  local event="${1:-}"
  local result="${2:-info}"
  local details="${3:-}"
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$ts" "$AUDIT_SCRIPT_NAME" "$event" "$result" "$details" \
    >> "$AUDIT_LOG_PATH"
}

# audit_setup
#   スクリプト先頭で呼ぶ。開始ログ + 終了時のログを仕込む（成功・失敗を自動判別）。
audit_setup() {
  audit_log "start" "info" "args: $*"
  # shellcheck disable=SC2154  # __rc は trap 内で $? から代入される（同一式内のため shellcheck は検知不可）
  trap '__rc=$?; if [ $__rc -eq 0 ]; then audit_log "exit" "ok" ""; else audit_log "exit" "fail" "exit_code=$__rc"; fi' EXIT
}
