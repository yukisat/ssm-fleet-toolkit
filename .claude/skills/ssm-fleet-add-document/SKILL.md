---
name: ssm-fleet-add-document
description: |
  新しい claude-investigate-* SSM Document を対話的に追加するスキル。
  カテゴリ・名前・パラメータ・出力スキーマを聞き取り、document.yaml / metadata.yaml /
  README.md の 3 点セットを生成、catalog.json を更新する。
---

# ssm-fleet-add-document スキル

## トリガー

- 「新しい Document を追加したい」
- 「<X> を調べる Document を作って」
- 「<カテゴリ> に <名前> を追加」

## 基本原則

- 追加できるのは readonly のみ（`safety: readonly`）
- 命名は `claude-investigate-<category>-<name>` 必須
- 配置は `documents/readonly/claude-investigate/<category>/<name>/`
- ファイルは 3 点セット必須: `document.yaml`, `metadata.yaml`, `README.md`

## ワークフロー

### Step 1: 要件の聞き取り

AskUserQuestion で確認:

1. カテゴリ（os / nginx / php / wordpress / mysql / 等）
2. 名前（kebab-case）
3. 何を調べるか（説明）
4. 対応 OS
5. 必要パッケージ
6. パラメータ（必要なら）
7. 出力スキーマ（JSON 構造）

### Step 2: スクリプト本体の生成

利用者と相談しながら `document.yaml` の `runCommand` を書く。
原則:

- 出力は JSON にする（機械可読）
- エラーは標準エラーに出力し、終了コードを 0 にしない
- 副作用を起こさない（grep / awk / cat / df 等の readonly コマンドのみ）
- 危険コマンド（rm / chmod / kill / systemctl 等）は禁止

### Step 3: ファイル生成

`documents/readonly/claude-investigate/<category>/<name>/` を作成し、
3 ファイルを生成。

### Step 4: catalog.json 更新

`catalog.json` に新規エントリを追加（自動生成スクリプトが将来必要）。

### Step 5: テスト

可能であれば検証環境のインスタンスで実行し、出力スキーマと一致することを確認。

### Step 6: コミット提案

利用者に `git add` / `git commit` を提案。

## 安全ルール

- `documents/stateful/` への追加は絶対に行わない
- 危険コマンドを含む Document は提案しない（利用者から要求があっても理由を説明して断る）
- 顧客固有情報（顧客名、ドメイン、IP）をハードコードしない
- パラメータ化できるものはパラメータにする

## 参考

- `../../../documents/CLAUDE.md`: 命名・メタデータ規約
- `../../../documents/readonly/claude-investigate/os/disk-usage/`: 参考実装
