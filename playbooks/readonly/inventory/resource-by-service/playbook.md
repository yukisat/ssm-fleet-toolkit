# Playbook: サービス別リソース数一覧

## 目的

アカウント内の全リソースをサービス別にカウントする。未使用アカウントの棚卸し・想定外リソースの検出に使う。

## パラメータ

| 名前 | 例 | 説明 |
|---|---|---|
| region | `ap-northeast-1` | 調査対象リージョン |
| profile | `my-profile` | AWS CLI プロファイル |

## 実行

`GetResources` は 1 ページ最大 100 件。`PaginationToken` が返ってくる間ループする。

```bash
NEXT=""
declare -A counts
while :; do
  RESP=$(aws resourcegroupstaggingapi get-resources \
    --region "$REGION" --profile "$PROFILE" \
    --page-size 100 \
    ${NEXT:+--pagination-token "$NEXT"} \
    --output json)
  while IFS= read -r arn; do
    svc=$(echo "$arn" | cut -d: -f3)
    counts["$svc"]=$(( ${counts["$svc"]:-0} + 1 ))
  done < <(echo "$RESP" | jq -r '.ResourceTagMappingList[].ResourceARN')
  NEXT=$(echo "$RESP" | jq -r '.PaginationToken // empty')
  [ -z "$NEXT" ] && break
done

for svc in $(echo "${!counts[@]}" | tr ' ' '\n' | sort); do
  printf '%-40s %d\n' "$svc" "${counts[$svc]}"
done
```

jq で集計する場合（ページをまとめた後）:

```bash
# 全ページを 1 ファイルに蓄積してから集計
jq -s '[.[].ResourceTagMappingList[].ResourceARN | split(":")[2]] | group_by(.) | map({service: .[0], count: length}) | sort_by(.service)' /tmp/pages_*.json
```

## 全リージョン横断

```bash
REGIONS=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text --profile "$PROFILE")
for r in $REGIONS; do
  echo "=== $r ==="
  # 上記ループを region=$r で実行
done
```

## 注意点

- `tag:GetResources` はタグ付きリソースのみを返す。タグ未付与リソースはカウントされない
- IAM ユーザー・グループ・ロールはグローバルリソースのため `us-east-1` で取得する
- S3 バケットは `us-east-1` でリストされる場合がある（バケットのリージョンに関係なく）
- 全リージョン横断は時間がかかるため、対象が分かればリージョン指定を推奨
