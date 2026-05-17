# Playbook: SSM 管理インスタンス一覧

## 目的

SSM Agent が登録されているインスタンスを一覧取得する。Agent 未導入インスタンスの検出、プラットフォームバージョン確認、Ping 状態の確認に使う。

## パラメータ

| 名前 | 例 | 説明 |
|---|---|---|
| region | `ap-northeast-1` | 調査対象リージョン |
| profile | `my-profile` | AWS CLI プロファイル |
| ping_status | `Online` | 空で全件（Online / Inactive / ConnectionLost / Terminated） |

## 実行

`DescribeInstanceInformation` は 1 ページ最大 50 件。`--page-size 50` が必須（デフォルト 10 だとレートリミットで件数が半減する）。

```bash
NEXT=""
while :; do
  RESP=$(aws ssm describe-instance-information \
    --page-size 50 \
    --region "$REGION" --profile "$PROFILE" \
    ${NEXT:+--starting-token "$NEXT"} \
    --output json)
  echo "$RESP" | jq -r '
    .InstanceInformationList[] |
    [.InstanceId, .PingStatus, .LastPingDateTime, .PlatformType,
     .PlatformVersion, .AgentVersion, .IPAddress] |
    @tsv
  '
  NEXT=$(echo "$RESP" | jq -r '.NextToken // empty')
  [ -z "$NEXT" ] && break
done
```

特定の Ping ステータスでフィルタする場合:

```bash
aws ssm describe-instance-information \
  --filters "Key=PingStatus,Values=Online" \
  --page-size 50 \
  --region "$REGION" --profile "$PROFILE" \
  --query 'InstanceInformationList[].{Id:InstanceId,Status:PingStatus,OS:PlatformType,Ver:PlatformVersion,IP:IPAddress}' \
  --output table
```

## EC2 インスタンス一覧と突き合わせ（SSM 未登録検出）

```bash
# EC2 起動中インスタンス ID
EC2_IDS=$(aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --region "$REGION" --profile "$PROFILE" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text | tr '\t' '\n' | sort)

# SSM 登録済みインスタンス ID
SSM_IDS=$(aws ssm describe-instance-information \
  --page-size 50 --region "$REGION" --profile "$PROFILE" \
  --query 'InstanceInformationList[?starts_with(InstanceId, `i-`)].InstanceId' \
  --output text | tr '\t' '\n' | sort)

# SSM 未登録インスタンス（EC2 にあるが SSM にない）
comm -23 <(echo "$EC2_IDS") <(echo "$SSM_IDS")
```

## 注意点

- `--page-size 50` を必ず付ける（省略するとデフォルト 10 になりスロットリングが発生しやすい）
- マネージドノード（EC2 以外）も含まれる場合がある（`InstanceId` が `mi-` で始まる）
- Ping ステータスが `Online` でも、IAM 権限不足で Document 実行が失敗する場合がある
- 全リージョン横断は `ec2:DescribeRegions` でリージョン一覧を取得してからループする
