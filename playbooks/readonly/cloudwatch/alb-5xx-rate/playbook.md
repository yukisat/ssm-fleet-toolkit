# Playbook: ALB 5xx 率取得

## 目的

ALB の 5xx エラー数と総リクエスト数を時系列で取得し、エラー率と原因切り分け（ALB / Target）を行う。

## パラメータ

| 名前 | 例 | 説明 |
|---|---|---|
| load_balancer_arn | `arn:aws:...:loadbalancer/app/myalb/abc123def456` | 対象 ALB の ARN |
| time_from | `2026-05-15T00:00:00Z` | 集計開始 |
| time_to | `2026-05-15T01:00:00Z` | 集計終了 |
| period_seconds | `60` | 間隔（秒） |

ARN の suffix（`app/myalb/abc123def456`）部分が CloudWatch ディメンションになるので注意。

## 実行手順

### 1. ARN suffix の抽出

```bash
ALB_ARN="arn:aws:elasticloadbalancing:ap-northeast-1:123456789012:loadbalancer/app/myalb/abc123def456"
LB_DIM=$(echo "$ALB_ARN" | awk -F'loadbalancer/' '{print $2}')
# LB_DIM = "app/myalb/abc123def456"
```

### 2. CloudWatch GetMetricData 実行

```bash
aws cloudwatch get-metric-data \
  --metric-data-queries '[
    {
      "Id": "req",
      "MetricStat": {
        "Metric": {
          "Namespace": "AWS/ApplicationELB",
          "MetricName": "RequestCount",
          "Dimensions": [{"Name": "LoadBalancer", "Value": "'"$LB_DIM"'"}]
        },
        "Period": '"$PERIOD"',
        "Stat": "Sum"
      }
    },
    {
      "Id": "elb5xx",
      "MetricStat": {
        "Metric": {
          "Namespace": "AWS/ApplicationELB",
          "MetricName": "HTTPCode_ELB_5XX_Count",
          "Dimensions": [{"Name": "LoadBalancer", "Value": "'"$LB_DIM"'"}]
        },
        "Period": '"$PERIOD"',
        "Stat": "Sum"
      }
    },
    {
      "Id": "target5xx",
      "MetricStat": {
        "Metric": {
          "Namespace": "AWS/ApplicationELB",
          "MetricName": "HTTPCode_Target_5XX_Count",
          "Dimensions": [{"Name": "LoadBalancer", "Value": "'"$LB_DIM"'"}]
        },
        "Period": '"$PERIOD"',
        "Stat": "Sum"
      }
    }
  ]' \
  --start-time "$TIME_FROM" \
  --end-time "$TIME_TO" \
  --profile "$PROFILE"
```

`get-metric-data` は 1 レスポンスあたり最大 100,800 datapoints / 約 1MB。期間と period の組み合わせで超える場合は `NextToken` が返るので必ずループする:

```bash
NEXT=""
while :; do
  RESP=$(aws cloudwatch get-metric-data \
    --metric-data-queries "$QUERIES" \
    --start-time "$TIME_FROM" --end-time "$TIME_TO" \
    --profile "$PROFILE" \
    ${NEXT:+--next-token "$NEXT"} --output json)
  echo "$RESP" | jq '.MetricDataResults'
  NEXT=$(echo "$RESP" | jq -r '.NextToken // empty')
  [ -z "$NEXT" ] && break
done
```

CLI のオートページネーションを使う場合は `--no-paginate` を付けない。

### 3. 結果の解釈

`metadata.yaml` の `claude_hints` 参照:

- elb_5xx / target_5xx の比率で原因切り分け
- 5xx_rate = (elb_5xx + target_5xx) / request_count
- 1% 超 → 警告、5% 超 → 緊急対応

## 関連

- ALB アクセスログの直接調査が必要なら Athena 経由
- Target レベルの調査は EC2 instance の SSM Document（process-list, php-error-log 等）
