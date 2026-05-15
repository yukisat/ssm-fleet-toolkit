# claude-investigate-os-memory-usage

メモリとスワップの使用量を JSON で取得する readonly Document。

## 使い方

```bash
aws ssm send-command \
  --document-name claude-investigate-os-memory-usage \
  --instance-ids i-xxxxxxxxxxxx
```

## 出力例

```json
{
  "total_bytes": 16777216000,
  "available_bytes": 8388608000,
  "used_bytes": 8388608000,
  "use_percent": 50.0,
  "buffers_bytes": 104857600,
  "cached_bytes": 2097152000,
  "swap_total_bytes": 4294967296,
  "swap_used_bytes": 0,
  "swap_use_percent": 0.0
}
```

## 判定ヒント

- `use_percent` は MemAvailable ベース。Buffers / Cached を除く実質使用率
- `swap_use_percent > 50` はスワップ多発、性能劣化の可能性
- `swap_total_bytes == 0` は swap 未設定、OOM 時に即停止のリスク
- `available_bytes` が極端に小さい場合 OOM Killer 発火の前兆
