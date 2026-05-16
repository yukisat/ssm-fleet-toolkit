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

## 全リージョン横断

```bash
REGIONS=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text --profile "$PROFILE")
for r in $REGIONS; do
  echo "=== $r ==="
  aws ec2 describe-instances --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" \
    --region "$r" --profile "$PROFILE" --query 'Reservations[].Instances[].InstanceId' --output text
done
```

## SSM Online 状態の確認

```bash
aws ssm describe-instance-information --page-size 50 --region "$REGION" --profile "$PROFILE" \
  --query 'InstanceInformationList[?starts_with(InstanceId, `i-`)].{Id:InstanceId,Online:PingStatus,LastPing:LastPingDateTime}' \
  --output table
```

## 注意点

- `--page-size 50` を必ず付ける（デフォルト 10 だとレートリミットで件数半減）
- 全リージョン横断は時間がかかる、対象が分かれば region 指定
