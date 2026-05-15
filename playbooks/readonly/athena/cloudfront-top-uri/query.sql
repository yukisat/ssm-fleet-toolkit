-- CloudFront アクセスログ Top URI 集計
--
-- パラメータ（呼び出し側で置換）:
--   {DATABASE}        : Glue データベース名
--   {TABLE}           : CloudFront ログテーブル名
--   {DISTRIBUTION_ID} : 対象ディストリビューション ID
--   {TIME_FROM}       : 集計開始時刻（UTC, ISO 8601）
--   {TIME_TO}         : 集計終了時刻
--   {TOP_N}           : 上位件数

SELECT
  cs_uri_stem AS uri,
  COUNT(*) AS request_count,
  AVG(sc_bytes) AS avg_bytes,
  SUM(sc_bytes) AS total_bytes,
  COUNT(DISTINCT c_ip) AS distinct_clients
FROM
  "{DATABASE}"."{TABLE}"
WHERE
  distribution_id = '{DISTRIBUTION_ID}'
  AND from_iso8601_timestamp(
        concat(date_format(date, '%Y-%m-%d'), 'T', time)
      ) BETWEEN from_iso8601_timestamp('{TIME_FROM}')
            AND from_iso8601_timestamp('{TIME_TO}')
GROUP BY
  cs_uri_stem
ORDER BY
  request_count DESC
LIMIT {TOP_N};
