# playbooks/

AWS API 経由の調査手順書を配置するディレクトリ。Document（SSM）が OS 内部調査を担当するのに対し、playbook は AWS 環境調査（Athena・CloudWatch・EC2 describe など）を担当する。

## ディレクトリ構造（予定）

```
readonly/
├── athena/
│   ├── cloudfront-top-uri/
│   │   ├── playbook.md      # Claude が読む手順書
│   │   ├── query.sql        # 実行する Athena クエリ
│   │   └── metadata.yaml
│   └── ...
├── cloudwatch/
│   ├── alb-5xx-rate/
│   └── ec2-cpu-spike/
└── ec2/
    └── describe-by-tag/
```

## 状態

**スタブのみ**。次のマイルストーンで以下を実装予定:

- Athena: CloudFront ログ Top URI / エラー率
- CloudWatch: ALB 5xx 率 / EC2 CPU
- EC2: タグベースのインスタンス特定

## 設計

- `metadata.yaml` は Document と同じ思想（safety: readonly, claude_hints 等）
- `catalog.json` に `playbooks` セクションとして統合
- Claude がカテゴリ横断で適切な手段を選べる構造を目指す

## 共通規約

### ページネーション

AWS API は 1 レスポンスの件数 / サイズに上限があり、超過時は `NextToken` で続きを取得する。**ページネーションを省くと取りこぼしが発生**するため、調査系 playbook では必須:

- CLI のオートページネーションを使う（`--no-paginate` を**付けない**）か、`NextToken` を明示ループする
- `--page-size` をデフォルト値より大きく指定してリクエスト回数を減らす（例: `aws ssm describe-instance-information --page-size 50`、`aws ec2 describe-instances --max-results 1000`）
- `metadata.yaml` の `pagination` フィールドに API ごとの上限・トークンフィールド名を記載

### Athena のリージョン整合（S3 と同一リージョンで実行）

**Athena は「クエリを実行するリージョン」にある S3 データしか参照できない。**
S3 上のログ（CloudFront ログ等）を分析するときは、**対象データを置いている S3 バケットのリージョンを必ず先に確認し、Athena・結果バケット・WorkGroup をすべてそのリージョンに揃えて実行する**こと。リージョンを取り違えるとテーブルが見つからない・データを読めない。

- 実行前にバケットのリージョンを確認する: `aws s3api get-bucket-location --bucket <bucket>`（`us-east-1` は `None`/空で返る）
- CloudFront ログの場合: `aws cloudfront get-distribution-config --id <dist> --query 'DistributionConfig.Logging.Bucket'` で出力先を特定 → 上記でリージョン確認
- 以降の `aws athena` / `aws s3api` コマンドはすべて `--region <そのリージョン>` で揃える
- 許可リージョン（権限上 Athena 実行・結果バケット作成が可能）: **ap-northeast-1 / us-west-2**

### Athena コスト制御

Athena はスキャンしたデータ量で課金される（$5/TB）。誤った WHERE 句や partition 指定漏れで暴走しないよう、**多層防御**を必須とする:

1. **専用 WorkGroup を使う**（`primary` を直接使わない）
   - `BytesScannedCutoffPerQuery` — クエリ単位の絶対上限（推奨 10 GiB）
   - `EnforceWorkGroupConfiguration: true` — クライアント側で上書き不可
   - `ResultConfiguration.EncryptionConfiguration` — 結果バケット暗号化
   - `PublishCloudWatchMetricsEnabled: true` — スキャン量をメトリクス監視
2. **partition pruning 必須** — WHERE 句で year/month/day/hour を指定。partition projection 推奨
3. **事前ドライラン** — 短期間で実績スキャン量を取得し、本番期間に外挿してから本番実行
4. **実績の事後確認** — `DataScannedInBytes` を `get-query-execution` で確認し、見積もりとの乖離を検知

各 Athena playbook の `metadata.yaml` に `cost_controls` フィールドで設定値を明示する。
