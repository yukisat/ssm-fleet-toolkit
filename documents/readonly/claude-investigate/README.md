# claude-investigate Documents

readonly な調査用 SSM Document を配置するルート。

## ディレクトリ構造

```
<category>/<name>/
├── document.yaml    # SSM Document 本体
├── metadata.yaml    # 機械可読メタデータ
└── README.md        # 人間向け説明
```

## カテゴリ一覧

- `os/`: OS 共通（disk、process、memory 等）
- 今後追加予定: `nginx/`, `php/`, `wordpress/`, `mysql/`, `apache/` 等

詳細は `../../CLAUDE.md` 参照。
