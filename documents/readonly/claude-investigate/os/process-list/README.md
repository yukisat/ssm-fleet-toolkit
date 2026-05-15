# claude-investigate-os-process-list

CPU またはメモリ使用率の上位プロセスを取得する readonly Document。

## 使い方

```bash
aws ssm send-command \
  --document-name claude-investigate-os-process-list \
  --instance-ids i-xxxxxxxxxxxx \
  --parameters TopN=20,SortKey=cpu
```

## パラメータ

- `TopN`: 取得する上位プロセス数（デフォルト 20）
- `SortKey`: `cpu`（CPU 使用率順）または `mem`（メモリ使用率順）。デフォルト `cpu`

## 出力例

```json
[
  {"pid":1234,"user":"nginx","cpu_percent":45.2,"mem_percent":2.1,"rss_kb":102400,"elapsed":"02:13:05","command":"nginx"},
  {"pid":5678,"user":"php-fpm","cpu_percent":30.5,"mem_percent":5.8,"rss_kb":204800,"elapsed":"01:30:00","command":"php-fpm"}
]
```

## 判定ヒント

- CPU 上位が `php-fpm` / `nginx` ワーカーなら通常負荷の延長を疑う
- 単一プロセスが 100% 近い → 無限ループや busy loop の可能性
- mem 上位が OOM の手前 → スワップ・swappiness も要確認
- `<defunct>` はゾンビプロセス、親プロセスの状態を確認
