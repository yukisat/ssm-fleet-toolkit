# Stateful Documents

このディレクトリは「サーバーの状態を変更する SSM Document」を配置する場所です。

## 現状

**意図的に空にしています**。本プロジェクト現時点では、変更を伴う操作を SSM Document として自動化することのリスクを優先し、readonly のみを提供しています。

## 将来追加する場合のルール

stateful Document を追加する判断は慎重に行う必要があります。追加時は以下を必ず守ること:

1. Document 名のプレフィックスは `ops-modify-*`（`claude-investigate-*` ではない）
2. メタデータに以下を必須記載:
   - `safety: stateful`
   - dry-run モードの有無
   - 変更前バックアップ取得手順
   - ロールバック手順
3. IAM ポリシーは `claude-investigate-*` 用と必ず分離
4. レビュー: 2 名以上必須、本番投入前に検証環境テスト必須
5. `ops-modify-*` を実行できる IAM ロールを別に用意し、調査用ロールには付与しない

## 検討中の候補（参考）

- nginx -t 後の reload（設定検証通過時のみ）
- ログローテート強制実行
- 一時ファイル削除

これらも基本は人手で行う方針で、Document 化は慎重に判断する。

## 関連

- `../../docs/safety-policy.md`: 安全ポリシー全体
- `../readonly/`: 現在使える調査用 Document
