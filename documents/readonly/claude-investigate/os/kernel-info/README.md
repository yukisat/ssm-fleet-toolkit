# claude-investigate-os-kernel-info

実行中カーネルのバージョン・インストール済みカーネルパッケージ・MPTCP 有効状態・利用可能なカーネルアップデートを JSON で取得する。

## 何をするか

- `uname -r` で実行中カーネルバージョン
- `rpm -qa` でインストール済みカーネルパッケージ一覧（kernel / kernel6.12 / kernel6.18 など系統別）
- `sysctl net.mptcp.enabled` で MPTCP の有効/無効
- `dnf check-update kernel*` で利用可能なアップデート

## 使い方

```bash
aws ssm send-command \
  --document-name claude-investigate-os-kernel-info \
  --instance-ids i-xxxxxxxxxxxx \
  --profile amimoto-claude-investigator
```

結果取得:

```bash
aws ssm get-command-invocation \
  --command-id <command-id> \
  --instance-id i-xxxxxxxxxxxx \
  --query StandardOutputContent --output text \
  --profile amimoto-claude-investigator
```

## 出力例

```json
{
  "running_kernel": "6.18.56-125.164.amzn2023.x86_64",
  "installed_packages": [
    "kernel6.18-6.18.56-125.164.amzn2023.x86_64"
  ],
  "mptcp_enabled": 0,
  "available_updates": [],
  "package_manager": "dnf"
}
```

## 判定ヒント（CVE-2026-98432）

| 状況 | リスク |
|---|---|
| kernel6.18 >= 6.18.56-125.164 | 修正済み |
| kernel6.12 >= 6.12.113-138.209 | 修正済み |
| 標準 kernel（修正版未リリース）かつ mptcp_enabled=0 | 低（MPTCP 経由の攻撃困難） |
| 標準 kernel かつ mptcp_enabled=1 | 高（緊急対応） |

## 関連

- `../listening-ports/`（LISTEN ポート確認）
- `../network-connections/`（TCP 接続状態）
