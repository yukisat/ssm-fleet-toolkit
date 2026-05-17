# Playbook: 当月予測コスト

## 目的

Cost Explorer で当月末までの予測コストを取得する。月末に向けたコスト見通しの確認・予算超過リスクの早期検出に使う。

## パラメータ

| 名前 | 例 | 説明 |
|---|---|---|
| profile | `my-profile` | AWS CLI プロファイル |
| end_date | `2026-06-01` | 予測終了日（空なら翌月 1 日） |

**注意**: Cost Explorer API は **us-east-1 固定**。1 リクエストあたり **$0.01** の料金が発生する。

## 実行

```bash
# 明日〜月末の予測（今日以降を予測対象にする）
START=$(date -d "tomorrow" +%Y-%m-%d 2>/dev/null || date -v+1d +%Y-%m-%d)
END=$(date -d "$(date +%Y-%m-01) + 1 month" +%Y-%m-%d 2>/dev/null || date -v+1m -v1d +%Y-%m-%d)

aws ce get-cost-forecast \
  --time-period "Start=${START},End=${END}" \
  --metric UNBLENDED_COST \
  --granularity MONTHLY \
  --region us-east-1 \
  --profile "$PROFILE" \
  --output json | jq '{
    total_forecast_usd: (.Total.Amount | tonumber | . * 100 | round / 100),
    lower_bound_usd: (.ForecastResultsByTime[0].PredictionIntervalLowerBound | tonumber | . * 100 | round / 100),
    upper_bound_usd: (.ForecastResultsByTime[0].PredictionIntervalUpperBound | tonumber | . * 100 | round / 100)
  }'
```

## 日次予測（コスト急増の検出）

```bash
aws ce get-cost-forecast \
  --time-period "Start=${START},End=${END}" \
  --metric UNBLENDED_COST \
  --granularity DAILY \
  --region us-east-1 \
  --profile "$PROFILE" \
  --output json | jq -r '
    .ForecastResultsByTime[] |
    [.TimePeriod.Start,
     (.MeanValue | tonumber | . * 100 | round / 100),
     (.PredictionIntervalLowerBound | tonumber | . * 100 | round / 100),
     (.PredictionIntervalUpperBound | tonumber | . * 100 | round / 100)] |
    @tsv
  '
```

## 当月実績 + 予測の合算（月全体のコスト見通し）

```bash
MONTH_START=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d 2>/dev/null || date -v1d +%Y-%m-%d)
TODAY=$(date +%Y-%m-%d)
MONTH_END=$(date -d "$(date +%Y-%m-01) + 1 month" +%Y-%m-%d 2>/dev/null || date -v+1m -v1d +%Y-%m-%d)

# 実績（月初〜昨日）
ACTUAL=$(aws ce get-cost-and-usage \
  --time-period "Start=${MONTH_START},End=${TODAY}" \
  --granularity MONTHLY --metrics UnblendedCost \
  --region us-east-1 --profile "$PROFILE" \
  --output json | jq -r '.ResultsByTime[0].Total.UnblendedCost.Amount // "0"')

# 予測（今日〜月末）
FORECAST=$(aws ce get-cost-forecast \
  --time-period "Start=${TODAY},End=${MONTH_END}" \
  --metric UNBLENDED_COST --granularity MONTHLY \
  --region us-east-1 --profile "$PROFILE" \
  --output json | jq -r '.Total.Amount // "0"')

echo "実績: ${ACTUAL} USD"
echo "予測: ${FORECAST} USD"
python3 -c "print(f'月末見込み: {float(\"${ACTUAL}\") + float(\"${FORECAST}\"):.2f} USD')"
```

## 注意点

- `GetCostForecast` の `Start` は**今日以降**でないとエラー（過去日は指定不可）
- 月初（1〜3 日）は実績データが少なく予測精度が低い
- `PredictionIntervalLowerBound` / `UpperBound` は 80% 信頼区間
- コスト急増が見込まれる場合は `cost/monthly-by-service` でサービス別内訳を確認する
- `date -d` は Linux 形式、macOS では `-v` 形式（上記コマンドは両方対応済み）
