# Playbook: 当月サービス別コスト

## 目的

Cost Explorer で当月のサービス別コストを取得する。コスト急増の原因サービス特定・月次コスト確認に使う。

## パラメータ

| 名前 | 例 | 説明 |
|---|---|---|
| profile | `my-profile` | AWS CLI プロファイル |
| start_date | `2026-05-01` | 空なら当月 1 日 |
| end_date | `2026-06-01` | 空なら翌月 1 日（終了日は含まない） |

**注意**: Cost Explorer API は **us-east-1 固定**。`--region us-east-1` を必ず付ける。1 リクエストあたり **$0.01** の料金が発生する。

## 実行

```bash
# 当月の開始日・終了日を自動計算
START=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d 2>/dev/null || date -v1d +%Y-%m-%d)
END=$(date -d "$(date +%Y-%m-01) + 1 month" +%Y-%m-%d 2>/dev/null || date -v+1m -v1d +%Y-%m-%d)

aws ce get-cost-and-usage \
  --time-period "Start=${START},End=${END}" \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --region us-east-1 \
  --profile "$PROFILE" \
  --output json | jq -r '
    .ResultsByTime[0].Groups[] |
    [.Keys[0], (.Metrics.UnblendedCost.Amount | tonumber | . * 100 | round / 100), .Metrics.UnblendedCost.Unit] |
    @tsv
  ' | sort -t$'\t' -k2 -rn
```

## 特定期間（過去月との比較）

```bash
# 前月
PREV_START=$(date -d "$(date +%Y-%m-01) - 1 month" +%Y-%m-%d 2>/dev/null || date -v-1m -v1d +%Y-%m-%d)
PREV_END=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d 2>/dev/null || date -v1d +%Y-%m-%d)

aws ce get-cost-and-usage \
  --time-period "Start=${PREV_START},End=${PREV_END}" \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --region us-east-1 --profile "$PROFILE" \
  --output json | jq '[.ResultsByTime[0].Groups[] | {service: .Keys[0], cost: (.Metrics.UnblendedCost.Amount | tonumber)}] | sort_by(-.cost)'
```

## 日次コスト推移（コスト急増日の特定）

```bash
aws ce get-cost-and-usage \
  --time-period "Start=${START},End=${END}" \
  --granularity DAILY \
  --metrics UnblendedCost \
  --region us-east-1 --profile "$PROFILE" \
  --output json | jq -r '
    .ResultsByTime[] |
    [.TimePeriod.Start, (.Total.UnblendedCost.Amount | tonumber | . * 100 | round / 100)] |
    @tsv
  '
```

## 注意点

- Cost Explorer は **us-east-1** でのみ利用可能（他リージョンを指定するとエラー）
- `--time-period` の `End` は**含まない**（当月全体なら翌月 1 日を指定）
- `UnblendedCost` が実際の請求に近い（`BlendedCost` は組織一括請求の按分後）
- 0.005 USD 未満のサービスは集計に含まれない場合がある
- `date -d` は Linux 形式、macOS では `-v` 形式（上記コマンドは両方対応済み）
