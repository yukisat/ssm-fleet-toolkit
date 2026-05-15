# 既知の落とし穴と対策

実運用で遭遇する可能性が高い問題と回避策をまとめています。

## AWS API / 操作系

### 1. `aws ssm describe-instance-information` の件数が半減する

**現象**: 多数のインスタンスがある環境で API 応答が不完全になる。

**原因**: デフォルトの `--page-size 10` が小さすぎてレートリミットに引っかかる。

**対策**: 常に `--page-size 50` を付ける。

```bash
aws ssm describe-instance-information --page-size 50 ...
```

### 2. ASG メンバーをフィルタする JMESPath が複雑

**現象**: `aws ec2 describe-instances` で ASG 配下のインスタンスを取得する書き方を間違えやすい。

**対策**: タグ名は `aws:autoscaling:groupName`（コロン要エスケープ）。

```bash
aws ec2 describe-instances --filters "Name=tag:aws:autoscaling:groupName,Values=*"
```

### 3. SSM SendCommand が一部インスタンスで silent fail

**現象**: 多台数に SendCommand しても、一部インスタンスは結果が返らない。

**原因**: SSM Online でも内部的に Agent 通信が不安定なケース。

**対策**:
- `--max-concurrency 10` 程度に絞る
- 失敗インスタンスは個別リトライ
- `get-command-invocation` で個別状態を必ず確認

### 4. SSM Online ステータスが古い

**現象**: コンソールで Online と表示されるが、実際には Agent が止まっている。

**対策**: SendCommand してみるのが最終確認。describe-instance-information の `LastPingDateTime` も併用。

### 5. `aws s3 ls` 結果と CloudFront 設定で参照バケットが食い違う

**現象**: CloudFront Origin と異なるバケットでファイルが管理されている。

**対策**: 必ず CloudFront Distribution の DescribeDistribution で Origin を一次ソースとする。

## Terraform 系

### 6. terraform plan で不要な diff が出る

**現象**: 何も変えていないのに `update in-place` が出る。

**よくある原因**:
- AWS Provider のバージョンアップで内部表現が変わった
- リソースが手動で変更された（drift）
- ignore_changes 設定漏れ

**対策**: diff の中身を読み、意図しないものなら `ignore_changes` 追加か手動で再同期。

### 7. CloudFormation StackSet が concurrent operation エラー

**現象**: 既に別の StackSet 操作が走っているとエラー。

**対策**: 完了まで待つ。`aws cloudformation describe-stack-set-operation` で進捗確認。

### 8. SSO permission set の inline policy が 10KB 上限

**現象**: ポリシー追加時に PolicyTooLargeException。

**対策**:
- 不要な権限を削る
- AWS managed policy で代替できる部分は移行
- 機能フラグで分割（このツールでは実装済み）

## シェル / スクリプト系

### 9. zsh での word splitting 動作差異

**現象**: bash で動く `for x in $var` が zsh で 1 要素扱いになる。

**対策**: スクリプトは `#!/usr/bin/env bash` を明示。zsh から source しない。
配列を使う場合は `"${array[@]}"` で展開。

### 10. macOS の bash 3.2 で `mapfile` / `declare -A` が使えない

**現象**: bash 4+ 機能を使ったスクリプトが macOS デフォルト bash で動かない。

**対策**:
- macOS 用スクリプトでは bash 3.2 互換を保つ
- `mapfile` の代わりに `while read` ループ
- `declare -A` の代わりに「キー=値」文字列で管理

### 11. SSM Document 内の `{{ Parameter }}` 展開と shell の干渉

**現象**: `runCommand` 内の `{{ Domain }}` 等が想定外の展開をする。

**対策**:
- パラメータを最初に変数に代入（`DOMAIN='{{ Domain }}'`）
- ダブルクォートで囲んで利用
- 空文字判定は `[ -z "$DOMAIN" ]`

### 12. 大量パラメータの heredoc が SSM Document サイズ制限に当たる

**現象**: Document が 65536 バイトを超えるとアップロードできない。

**対策**:
- 共通ロジックを別 Document に分離して chain
- 必要最小限の実装に絞る
- パラメータ化で複数 Document を 1 つに統合

## Glue / Athena 系

### 13. partition projection 未設定で Athena が全データスキャン

**現象**: 期間絞り込みしているのに料金が高額。

**対策**: テーブル DDL で `partition projection` を有効化（特に CloudFront / ALB ログ）。

### 14. Athena 結果バケットの S3 ライフサイクル未設定

**現象**: クエリ結果が蓄積し続けて S3 コストが増える。

**対策**: 結果バケットに 30 日削除のライフサイクルを設定。

## CloudFront / セキュリティ系

### 15. CloudFront ログの取得遅延

**現象**: アクセスログが S3 に到達するまで最大 1 時間程度遅延する。

**対策**: リアルタイム調査が必要なら CloudFront real-time logs（Kinesis 経由）に切り替え検討。
通常調査は遅延を許容して標準ログで OK。

### 16. WAF 検知では設定起因の脆弱性（CVE-2026-42945 等）を防げない

**現象**: WAF を入れていても、nginx の rewrite 設定起因の memory corruption はブロックできない。

**対策**: 設定スキャン（`claude-investigate-nginx-cve-pattern-scan`）で構成レベルから対策。

## このツール固有

### 17. catalog.json 自動生成に PyYAML 必須

**現象**: `./scripts/build-catalog.sh` 実行時に ModuleNotFoundError。

**対策**: `pip install pyyaml` で導入（システムが pip 制限している場合は venv 使用）。

### 18. terraform state を専用バケットに置かないと既存と混ざる

**現象**: state が他プロジェクトと衝突する。

**対策**: `<account-id>-ssm-fleet-tf-state` 命名のバケットを必ず使う（`bootstrap/02-create-tf-backend.sh` が作成）。
