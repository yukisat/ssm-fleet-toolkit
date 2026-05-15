# claude-investigate-os-disk-usage

ディスク使用量を JSON 形式で取得する readonly 調査 Document。

## 何をするか

各マウントポイントの容量・使用量・使用率を取得して機械可読な JSON 配列で返す。

## 使い方

```bash
aws ssm send-command \
  --document-name claude-investigate-os-disk-usage \
  --instance-ids i-xxxxxxxxxxxx
```

結果取得:

```bash
aws ssm get-command-invocation \
  --command-id <command-id> \
  --instance-id i-xxxxxxxxxxxx \
  --query StandardOutputContent --output text
```

## 出力例

```json
[
  {"mount":"/","size_bytes":21474836480,"used_bytes":5368709120,"available_bytes":16106127360,"use_percent":25},
  {"mount":"/var","size_bytes":107374182400,"used_bytes":53687091200,"available_bytes":53687091200,"use_percent":50}
]
```

## 判定ヒント

- 使用率 80% 以上を warn、95% 以上を critical の目安
- `/tmp` `/var/log` の急増はアプリケーション側の問題シグナル
- tmpfs などの特殊マウントも含まれる

## 関連

- `../process-list/`（CPU/メモリ消費プロセス）
- `../memory-usage/`（メモリ使用量）
