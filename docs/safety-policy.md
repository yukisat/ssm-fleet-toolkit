# 安全ポリシー

## readonly のみ提供

このツールが提供する Document は readonly（状態を変更しない調査用）のみです。

### readonly の判定基準

| 区分 | 例 |
|---|---|
| readonly（提供） | `nginx -V`, `df -h`, `systemctl status`, `rpm -qa`, ログ tail |
| readonly（提供） | `nginx -t`（設定構文チェック、書き込みなし） |
| stateful（提供しない） | `systemctl reload`, `dnf update`, ログローテート強制実行 |
| stateful（提供しない） | パッケージインストール、設定ファイル書き換え、プロセスへの SIGTERM |

判断に迷う場合は readonly に該当しないと判断する。

## stateful Document の扱い

- `documents/stateful/` ディレクトリは意図的に空
- 追加の要望が出た場合は本ポリシーの変更を伴うため、慎重に検討する
- 追加する場合のルール:
  - 命名プレフィックスは `ops-modify-*`（`claude-investigate-*` ではない）
  - IAM ポリシーを `claude-investigate-*` 用と完全分離
  - dry-run モード、ロールバック手順、バックアップ取得を必須化
  - 2 名以上のレビュー、検証環境でのテストを必須化

## Claude Code が守るルール

CLAUDE.md にも明記:

- AWS への書き込み操作は必ず利用者の明示承認後
- `bootstrap/` 配下の事前定義スクリプトのみ実行（aws CLI の自由構築禁止）
- terraform apply 前は plan を提示
- 想定外のエラーは即時停止し、現在の状態を報告

## 命名規約による安全性

- Document 名 `claude-investigate-*`: readonly 専用と一目で識別可能
- IAM ロール名 `ssm-fleet-*`: ツール由来と識別可能、grep でリスト化容易
- 既存環境との衝突回避を構造的に担保

## 監査性

- すべてのセットアップ操作は `install-audit.log` に記録
- AWS API 呼び出しは CloudTrail に通常通り記録
- Terraform state は git 履歴で誰がいつ何を変えたか追跡可能

## エスカレーション

ポリシー違反の疑いがある変更要求があった場合:

- Claude は要求を拒否し、理由を明示
- 利用者にポリシー変更が必要であることを伝える
- ポリシー変更は本ドキュメントの更新 + レビューが前提
