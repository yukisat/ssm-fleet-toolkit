# Playbook: Lightsail インスタンス・DB・LB 一覧

## 目的

Lightsail のインスタンス・データベース・ロードバランサーを一覧取得する。EC2 と別管理になっているため見落としやすい Lightsail リソースの棚卸しに使う。

## パラメータ

| 名前 | 例 | 説明 |
|---|---|---|
| region | `ap-northeast-1` | 調査対象リージョン |
| profile | `my-profile` | AWS CLI プロファイル |

## 実行

### インスタンス一覧

```bash
NEXT=""
while :; do
  RESP=$(aws lightsail get-instances \
    --region "$REGION" --profile "$PROFILE" \
    ${NEXT:+--page-token "$NEXT"} \
    --output json)
  echo "$RESP" | jq -r '
    .instances[] |
    [.name, .state.name, .bundleId, .publicIpAddress // "none", .privateIpAddress] |
    @tsv
  '
  NEXT=$(echo "$RESP" | jq -r '.nextPageToken // empty')
  [ -z "$NEXT" ] && break
done
```

### データベース一覧

```bash
NEXT=""
while :; do
  RESP=$(aws lightsail get-relational-databases \
    --region "$REGION" --profile "$PROFILE" \
    ${NEXT:+--page-token "$NEXT"} \
    --output json)
  echo "$RESP" | jq -r '
    .relationalDatabases[] |
    [.name, .state, .relationalDatabaseBlueprintId, .masterDatabaseName] |
    @tsv
  '
  NEXT=$(echo "$RESP" | jq -r '.nextPageToken // empty')
  [ -z "$NEXT" ] && break
done
```

### ロードバランサー一覧

```bash
NEXT=""
while :; do
  RESP=$(aws lightsail get-load-balancers \
    --region "$REGION" --profile "$PROFILE" \
    ${NEXT:+--page-token "$NEXT"} \
    --output json)
  echo "$RESP" | jq -r '
    .loadBalancers[] |
    [.name, .state, .dnsName, (.instanceHealthSummary | length | tostring)] |
    @tsv
  '
  NEXT=$(echo "$RESP" | jq -r '.nextPageToken // empty')
  [ -z "$NEXT" ] && break
done
```

## まとめて取得（JSON 出力）

```bash
echo '{
  "instances": '$(aws lightsail get-instances --region "$REGION" --profile "$PROFILE" --output json | jq '.instances')',
  "databases": '$(aws lightsail get-relational-databases --region "$REGION" --profile "$PROFILE" --output json | jq '.relationalDatabases')',
  "load_balancers": '$(aws lightsail get-load-balancers --region "$REGION" --profile "$PROFILE" --output json | jq '.loadBalancers')'
}' | jq .
```

## 注意点

- Lightsail は EC2 の `describe-instances` に含まれない。`resource-by-service` playbook でも `lightsail` が出てこない場合がある
- `bundle_id` の対応表: `nano_2_0` (1CPU/512MB), `micro_2_0` (1CPU/1GB), `small_2_0` (1CPU/2GB), `medium_2_0` (2CPU/4GB) 等
- Lightsail インスタンスは SSM Agent 導入が別途必要（`ssm-managed-instances` playbook では見えない）
- 一部のリージョンでは Lightsail が利用できない
