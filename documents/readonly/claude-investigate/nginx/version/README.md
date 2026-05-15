# claude-investigate-nginx-version

nginx のバージョン・ビルド情報・有効モジュールを取得する readonly Document。

## 使い方

```bash
aws ssm send-command \
  --document-name claude-investigate-nginx-version \
  --instance-ids i-xxxxxxxxxxxx
```

## パラメータ

- `NginxBinary`: nginx バイナリパス（デフォルト `/usr/sbin/nginx`、見つからない場合は他の候補を自動探索）

## 出力例

```json
{
  "binary": "/usr/sbin/nginx",
  "version": "1.27.2",
  "built_with": "OpenSSL 3.0.13 30 Jan 2024",
  "tls_sni": "TLS SNI support enabled",
  "configure_arguments": ["--prefix=/etc/nginx", "--with-http_ssl_module", "..."]
}
```

## 判定ヒント

- `version` を CVE 対象範囲と照合
- `built_with` の OpenSSL バージョン由来の CVE もチェック
- `configure_arguments` でモジュール構成を確認
- パッケージ管理外（独自ビルド）の nginx は `/usr/local/nginx/sbin/` 等にある場合あり
