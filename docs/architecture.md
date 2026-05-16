# アーキテクチャ

## 設計目標

1. **インフラ事業者が誰でも使える汎用ライブラリ**として提供する
2. **Claude Code 経由での導入・運用**を前提とする AI-native 設計
3. **既存 AWS 環境に後付けで安全に差し込める**こと
4. **段階的に公開度を上げる**（private → 組織展開 → OSS）

## 全体構造

```
ssm-fleet-toolkit/
├── documents/      OS 内部調査の SSM Document ライブラリ（汎用）
├── playbooks/      AWS API 調査の手順書（Athena・CloudWatch 等）
├── modules/        Terraform モジュール（Document 配布・権限・StackSet）
├── deployments/    利用者環境ごとのひな形（_templates/ 配下）
├── bootstrap/      事前定義スクリプトと IAM ポリシー JSON
├── .claude/skills/ 運用スキル（セットアップ・調査・追加）
├── catalog.json    Document / playbook の機械可読インデックス
└── docs/           設計・安全ポリシー・FAQ
```

## 3 層分離の原則

| 層 | 内容 | 組織依存 |
|---|---|---|
| Document / playbook 本体 | 調査ロジック | なし（完全汎用） |
| Terraform モジュール | 登録・配布・権限の仕組み | なし（汎用モジュール） |
| deployments | アカウント ID・対象リージョン・共有先 | あり（組織固有） |

上 2 層を「ライブラリ」として汎用化、最下層は各組織のプライベートリポジトリで管理する。

## 環境タイプ

3 種類すべてに同じモジュールで対応:

- 単一 AWS アカウント
- AWS Organizations（推奨、SSO 統合可能）
- 手動マルチアカウント（Organizations 未使用）

`modules/ssm-document` の `shared_account_ids` 変数が空配列なら共有なしで動作する、など、モジュール側で環境差を吸収。

## Document の安全性設計

- `documents/readonly/` 配下のみ。状態を変更する Document は配置しない
- `documents/stateful/` は意図的に空（将来用プレースホルダ）
- 命名規約 `claude-investigate-*` で IAM ポリシーが prefix で絞れる
- メタデータ（`metadata.yaml`）で `safety: readonly` を機械可読に明示

## 権限設計

### インストーラ権限（一時）

セットアップ時のみ必要な強い権限。完了後に削除可能。
詳細は `required-permissions.md` と `bootstrap/installer-policy.json`。

### オペレータ権限（恒久）

日常運用で Claude が使う最小権限。機能ごとに分離:

- SSM Document 実行（必須）
- Athena クエリ（任意）
- CloudWatch 読み取り（任意）

inline policy JSON ファイルで分離し、`modules/sso-permission-set` で合成する。

## Claude Code との統合

- `CLAUDE.md`: リポジトリ全体の指針（短く、地図に徹する）
- サブ `CLAUDE.md`: 編集対象ごとに必要時のみ読まれる
- `.claude/skills/`: 利用者の意図ごとに起動するスキル
- `catalog.json`: Document / playbook の自動生成インデックス
- 各 Document の `metadata.yaml` に `claude_hints` を埋め込み、結果解釈を支援

## 既存環境との非破壊性

- すべてのリソース名に `ssm-fleet-*` または `claude-investigate-*` プレフィックス
- 既存リソースは `data` source で参照のみ、`resource` で管理しない
- Terraform state は専用 backend（`<account>-ssm-fleet-tf-state`）に独立
- `terraform plan` で `0 to change, 0 to destroy` を常に確認可能
- `bootstrap/pre-flight-check.sh` で衝突を機械的に検出

詳細は `coexistence.md`。

## 公開戦略

このリポジトリは段階的に公開度を上げていく:

1. **検証フェーズ**: プライベートで設計検証・実用化
2. **限定共有フェーズ**: 信頼できる組織内で展開・実証
3. **OSS 公開フェーズ**: 汎用ツールとして公開

各フェーズの移行判断は、汎用性と顧客固有情報の混入有無を確認してから行う。
