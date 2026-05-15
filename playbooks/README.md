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
- `catalog.json` に `aws_playbooks` セクションとして統合
- Claude がカテゴリ横断で適切な手段を選べる構造を目指す
