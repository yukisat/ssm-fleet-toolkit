# Playbook: CloudFront Top URI 集計

## 目的

CloudFront アクセスログから期間内の Top URI を集計し、異常なアクセス集中（DDoS, bot 巡回, 設定ミス）を検出する。

## 前提

- CloudFront アクセスログが S3 に蓄積されている
- Glue データカタログに CloudFront ログテーブルが登録されている
- 実行ユーザーが Athena/Glue/S3 権限を持っている（`modules/sso-permission-set/policies/claude-investigator-athena.json` 参照）

## パラメータ

| 名前 | 必須 | 例 | 説明 |
|---|---|---|---|
| distribution_id | yes | `E1XXXXXXXXXXXX` | 対象ディストリビューション |
| time_from | yes | `2026-05-15T00:00:00Z` | 集計開始（UTC） |
| time_to | yes | `2026-05-15T01:00:00Z` | 集計終了（UTC） |
| top_n | no | `50` | 上位件数 |

## 実行手順

### 1. パラメータ確認

利用者に以下を聞き取る:
- 対象ディストリビューション ID
- 集計期間（時間範囲を短く保つことでコスト抑制）
- Glue データベース・テーブル名（環境固有）

### 2. クエリ準備

`query.sql` のプレースホルダを実値に置換:

```bash
sed -e "s/{DATABASE}/$DATABASE/g" \
    -e "s/{TABLE}/$TABLE/g" \
    -e "s/{DISTRIBUTION_ID}/$DIST_ID/g" \
    -e "s/{TIME_FROM}/$TIME_FROM/g" \
    -e "s/{TIME_TO}/$TIME_TO/g" \
    -e "s/{TOP_N}/$TOP_N/g" \
    query.sql > /tmp/query.sql
```

### 3. 専用 WorkGroup 経由でクエリ実行（コスト制御の中核）

`primary` WorkGroup は直接使わない。スキャン量上限を設定した専用 WorkGroup `ssm-fleet-investigator` を使う:

```bash
WORKGROUP="ssm-fleet-investigator"

QUERY_ID=$(aws athena start-query-execution \
  --query-string "$(cat /tmp/query.sql)" \
  --work-group "$WORKGROUP" \
  --query QueryExecutionId --output text \
  --profile <profile>)
```

WorkGroup は運用者が事前に 1 回だけ作成しておく:

```bash
aws athena create-work-group \
  --name ssm-fleet-investigator \
  --configuration '{
    "ResultConfiguration": {
      "OutputLocation": "s3://<account>-athena-query-results-ap-northeast-1/",
      "EncryptionConfiguration": {"EncryptionOption": "SSE_S3"}
    },
    "BytesScannedCutoffPerQuery": 10737418240,
    "EnforceWorkGroupConfiguration": true,
    "PublishCloudWatchMetricsEnabled": true,
    "RequesterPaysEnabled": false
  }' \
  --profile <profile>
```

主要な制御:

- `BytesScannedCutoffPerQuery: 10 GiB` — 上限超過時はクエリ強制中断。WHERE 句を外したり partition 指定漏れで暴走しても保険になる
- `EnforceWorkGroupConfiguration: true` — クライアントが OutputLocation・暗号化設定を上書き不可
- `EncryptionConfiguration: SSE_S3` — 結果バケット暗号化
- `PublishCloudWatchMetricsEnabled: true` — `AWS/Athena` Namespace でスキャン量・実行時間を可視化（コスト監視・アラート用）

### 3.1 事前スキャン量見積もり（推奨）

本番期間で投げる前に、短期間（例: 1 時間）でドライランしてスキャン量を確認し、本番期間に線形外挿する:

```bash
TEST_QUERY_ID=$(aws athena start-query-execution \
  --query-string "$(sed "s|{TIME_TO}|<time_from+1h>|" /tmp/query.sql)" \
  --work-group "$WORKGROUP" \
  --query QueryExecutionId --output text --profile <profile>)

# 完了後にスキャン量を確認
aws athena get-query-execution --query-execution-id "$TEST_QUERY_ID" \
  --query 'QueryExecution.Statistics.DataScannedInBytes' --output text \
  --profile <profile>
# 表示バイト数 × (本番期間時間数 / 1) で本番見積もり
# $5/TB で換算 → 本番投入可否を判断
```

### 4. 完了待機

```bash
while true; do
  STATE=$(aws athena get-query-execution --query-execution-id "$QUERY_ID" \
    --query 'QueryExecution.Status.State' --output text --profile <profile>)
  case "$STATE" in
    SUCCEEDED) break ;;
    FAILED|CANCELLED) echo "Query $STATE"; exit 1 ;;
  esac
  sleep 2
done
```

`BytesScannedCutoffPerQuery` 超過時は `State=FAILED`、`StateChangeReason` に `Bytes scanned limit was exceeded` が入る。

### 5. 結果取得とスキャン量実績の確認

```bash
aws athena get-query-results --query-execution-id "$QUERY_ID" \
  --output json --profile <profile>

# 実績スキャン量・コストを確認
aws athena get-query-execution --query-execution-id "$QUERY_ID" \
  --query 'QueryExecution.Statistics.{Scanned:DataScannedInBytes,Millis:EngineExecutionTimeInMillis}' \
  --output table --profile <profile>
```

## 結果の解釈

`metadata.yaml` の `claude_hints` 参照:

- 上位 URI が突出 → DDoS/bot 巡回
- distinct_clients が少数 → 特定ソースからの攻撃
- 404 が上位 → 設定ミス・欠損コンテンツ

## コスト制御まとめ

Athena は **スキャンしたデータ量** で課金（$5/TB, 2026-05 時点）。本 playbook では多層防御で暴走を防ぐ:

1. **WorkGroup `BytesScannedCutoffPerQuery: 10 GiB`** — クエリ単位の絶対上限。設定漏れの最後の砦
2. **partition pruning** — `query.sql` の WHERE 句で `year/month/day/hour` を必ず指定。partition projection を使うとさらに高速
3. **事前ドライラン** — 短期間で実績を取り本番期間に外挿（手順 3.1）
4. **`EnforceWorkGroupConfiguration: true`** — クライアントが WorkGroup 設定を上書きできない
5. **CloudWatch メトリクス監視** — `AWS/Athena` Namespace の `ProcessedBytes` で異常検知アラート

参考: 1 時間範囲・partition pruning ありなら通常 $0.01 未満。1 日範囲で約 $0.10 〜 $0.50。

## 関連

- `../cloudfront-error-rate/` (未実装): 4xx / 5xx 率の時系列
- `../../cloudwatch/cloudfront-requests/` (未実装): リアルタイム監視
