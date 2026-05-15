# Playbook: EC2 CPU 統計取得

## 目的

EC2 インスタンスの CPU 使用率を時系列で取得する。スケーリング判断、CPU 高騰時の調査に利用。

## パラメータ

| 名前 | 例 | 説明 |
|---|---|---|
| instance_id | `i-0123456789abcdef0` | 対象インスタンス |
| time_from | `2026-05-15T00:00:00Z` | UTC |
| time_to | `2026-05-15T01:00:00Z` | UTC |
| period_seconds | `300` | 間隔（秒、60 or 300 推奨） |

## 実行

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
  --start-time "$TIME_FROM" \
  --end-time "$TIME_TO" \
  --period "$PERIOD" \
  --statistics Average Maximum \
  --profile "$PROFILE"
```

## 解釈

- `Average > 70%` 継続 → スケールアップ検討
- `Maximum` の短時間スパイクも見る（平均だけでは見逃す）
- 同時刻に process-list Document を実行して原因プロセス特定
