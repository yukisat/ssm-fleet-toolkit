# Playbook: タグ検索でインスタンス特定

## 目的

調査対象のインスタンスをタグで一括取得する。SSM Online 状態も合わせて確認。

## パラメータ

| 名前 | 例 | 説明 |
|---|---|---|
| tag_key | `Project` | タグキー |
| tag_value | `myproject-*` | 値（ワイルドカード可） |
| region | `ap-northeast-1` | 空なら全リージョン |

## 実行（単一リージョン）

`describe-instances` は 1 ページあたり最大 1000 件しか返らない（`MaxResults`）。100 台超の環境では `NextToken` を辿らないと取りこぼすため、AWS CLI 組み込みのオートページネーションを使う（`--no-paginate` を付けない）。

```bash
aws ec2 describe-instances \
  --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
            "Name=instance-state-name,Values=running,stopped" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Reservations[].Instances[].{
    InstanceId:InstanceId,
    State:State.Name,
    InstanceType:InstanceType,
    PrivateIp:PrivateIpAddress,
    Tags:Tags
  }' \
  --output json
```

明示ループしたい場合は `NextToken` を回す:

```bash
NEXT=""
while :; do
  RESP=$(aws ec2 describe-instances --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
    --region "$REGION" --profile "$PROFILE" --max-results 1000 \
    ${NEXT:+--starting-token "$NEXT"} --output json)
  echo "$RESP" | jq '.Reservations[].Instances[].InstanceId'
  NEXT=$(echo "$RESP" | jq -r '.NextToken // empty')
  [ -z "$NEXT" ] && break
done
```

## 全リージョン横断

```bash
REGIONS=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text --profile "$PROFILE")
for r in $REGIONS; do
  echo "=== $r ==="
  aws ec2 describe-instances --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
    --region "$r" --profile "$PROFILE" \
    --query 'Reservations[].Instances[].InstanceId' --output text
done
```

`describe-instances` は CLI のオートページネーションが効くので `--no-paginate` を付けない。全件取得が保証される。

## SSM Online 状態の確認

`describe-instance-information` は 1 ページあたり最大 50 件。50 台超の環境では `NextToken` ループが必須:

```bash
NEXT=""
while :; do
  RESP=$(aws ssm describe-instance-information \
    --page-size 50 --region "$REGION" --profile "$PROFILE" \
    ${NEXT:+--starting-token "$NEXT"} --output json)
  echo "$RESP" | jq -r '.InstanceInformationList[] | "\(.InstanceId)\t\(.PingStatus)\t\(.LastPingDateTime)"'
  NEXT=$(echo "$RESP" | jq -r '.NextToken // empty')
  [ -z "$NEXT" ] && break
done
```

ワンライナーで CLI のオートページネーションに任せる場合（`--no-paginate` を付けない）:

```bash
aws ssm describe-instance-information --page-size 50 --region "$REGION" --profile "$PROFILE" \
  --query 'InstanceInformationList[?starts_with(InstanceId, `i-`)].{Id:InstanceId,Online:PingStatus,LastPing:LastPingDateTime}' \
  --output table
```

## 注意点

- `--page-size 50` を必ず付ける（デフォルト 10 だとレートリミットで件数半減）
- ページネーションを止める `--no-paginate` は調査用途では使わない（取りこぼし防止）
- 全リージョン横断は時間がかかる、対象が分かれば region 指定
