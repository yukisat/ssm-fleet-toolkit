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

### 3. クエリ実行

```bash
QUERY_ID=$(aws athena start-query-execution \
  --query-string "$(cat /tmp/query.sql)" \
  --result-configuration OutputLocation=s3://<account>-athena-query-results-ap-northeast-1/ \
  --work-group primary \
  --query QueryExecutionId --output text \
  --profile <profile>)
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

### 5. 結果取得

```bash
aws athena get-query-results --query-execution-id "$QUERY_ID" \
  --output json --profile <profile>
```

## 結果の解釈

`metadata.yaml` の `claude_hints` 参照:

- 上位 URI が突出 → DDoS/bot 巡回
- distinct_clients が少数 → 特定ソースからの攻撃
- 404 が上位 → 設定ミス・欠損コンテンツ

## コスト

- Athena は **スキャンしたデータ量** で課金（$5/TB）
- 期間を短く保つ・partition projection で対象パーティションを絞ることが重要
- 1 時間範囲なら通常 $0.01 未満

## 関連

- `../cloudfront-error-rate/` (未実装): 4xx / 5xx 率の時系列
- `../../cloudwatch/cloudfront-requests/` (未実装): リアルタイム監視
