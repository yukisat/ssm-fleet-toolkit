---
name: ssm-fleet-investigate
description: |
  ssm-fleet-toolkit で配布された Document と playbook を使い、OS 内部 + AWS 環境を
  統合的に調査するスキル。catalog.json から手段を選び、Claude 自身が結果を解釈する。
---

# ssm-fleet-investigate スキル

## トリガー

- 「サーバーを調査して」「環境を見て」
- 「<アカウント> の <インスタンス ID> を調べて」
- 「500 エラー多発の原因を探って」
- 「ディスク逼迫してそう、確認して」

## 基本原則

- `documents/` と `playbooks/` の readonly 手段のみ使う
- `catalog.json` から候補を選ぶ（手段の自由構築は禁止）
- 結果は metadata.yaml の `claude_hints` を参考に解釈
- 取得情報は同一アカウント内に留め、外部送信しない

## ワークフロー

### Step 1: 対象とゴールの確認

利用者から以下を聞き取る（必要に応じ AskUserQuestion）:

- 対象アカウント（profile 名）
- 対象リージョン
- 対象リソース（インスタンス ID、ディストリビューション ID 等）
- 調査ゴール（何を確認したいか）

### Step 2: 調査手段の選定

`catalog.json` から該当する Document / playbook を選ぶ。
複数手段を組み合わせる場合は順序を明示し利用者に提示。

例:
- 「サイトが遅い」
  → `claude-investigate-os-load-average` で負荷確認
  → `claude-investigate-os-process-list` で CPU 上位プロセス
  → `claude-investigate-nginx-active-connections` で接続数
  → 必要なら Athena でアクセスログ解析

### Step 3: 実行

SSM Document の場合:
```
aws ssm send-command --document-name <name> --instance-ids <id> --profile <profile>
```

playbook の場合は手順に従って AWS API 呼び出し。

### Step 4: 結果の解釈

metadata.yaml の `claude_hints` と `output_schema` を参照し、
警告レベル・異常値を判定する。

### Step 5: 利用者への報告

- 何を調査したか
- 結果サマリ（数値）
- 異常検出があれば原因仮説
- 次に取りうるアクション

## 安全ルール

- `claude-investigate-*` 以外の Document は使わない
- 同時実行は最大 N 台まで（catalog から判断、デフォルト 10）
- 本番環境タグ付きインスタンスは事前に利用者に確認

## 参考

- `catalog.json`: 利用可能な手段の一覧
- `documents/readonly/claude-investigate/`: Document 本体
- `playbooks/readonly/`: AWS API 調査手順
