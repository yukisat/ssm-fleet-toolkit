# セキュリティモデル

このツールがどのような脅威を想定し、どう対策しているかを整理します。

## 信頼境界

```
┌─────────────────────────────┐
│ 利用者のローカル端末          │ ← Claude Code 動作
│  ├─ ssm-fleet-toolkit (git) │
│  ├─ AWS CLI (SSO 認証)       │
│  └─ Terraform                │
└──────────┬──────────────────┘
           │ (HTTPS, SSO 認証)
           ▼
┌─────────────────────────────┐
│ AWS（利用者の組織）           │
│  ├─ 委任管理アカウント        │ ← Document・権限の集約点
│  └─ 子アカウント × N         │ ← 調査対象
└─────────────────────────────┘
```

利用者のローカル端末を信頼境界とし、AWS 側は最小権限で動作。

## 想定脅威と対策

### T1: Claude による意図しない AWS 操作

**脅威**: Claude が暴走して想定外のリソースを作成・削除・変更する。

**対策**:
- 事前定義スクリプトのみ実行（`bootstrap/` 配下）
- AWS CLI コマンドの自由構築を CLAUDE.md で禁止
- terraform apply 前に plan 提示と承認
- すべての書き込み操作は利用者の明示承認を経る

### T2: 過剰な権限の付与・蓄積

**脅威**: 必要以上の IAM 権限が長期間維持されてしまう。

**対策**:
- インストーラ権限とオペレータ権限の分離
- インストーラ権限はセットアップ後に削除可能
- オペレータ権限は機能ごとに opt-in（不要なら付与しない）
- すべて Terraform 管理で git history から変更を追跡可能

### T3: 既存リソースへの破壊的影響

**脅威**: 既存の AWS リソースが意図せず変更・削除される。

**対策**:
- すべてのリソース名に `ssm-fleet-*` / `claude-investigate-*` プレフィックス
- 既存リソースは `data` source で参照のみ（`resource` で管理しない）
- Terraform state を専用バケットに物理分離
- `terraform plan` で `0 to change, 0 to destroy` を毎回確認
- `bootstrap/pre-flight-check.sh` で衝突を機械的に検出

### T4: 認証情報・シークレットの漏洩

**脅威**: AWS アクセスキーや SSH 鍵が誤ってリポジトリにコミットされる。

**対策**:
- `.gitignore` で `*.pem`, `*.key`, `.env*`, `*.tfvars` を除外
- ライブラリ層（documents/, modules/, playbooks/）に顧客固有情報を含めない
- pre-commit hook で git-secrets / detect-secrets の利用を推奨（個別環境で）
- Document 自体に認証情報を埋め込まない（実行時パラメータか EC2 IAM ロールで取得）

### T5: サーバー上のデータ漏洩

**脅威**: 調査 Document が秘密情報（パスワード、秘密鍵）を意図せず取得する。

**対策**:
- すべての Document を readonly に限定
- 設定ファイルの存在確認のみで内容は読まない方針（必要な場合のみ最小限）
- `/etc/shadow`, `~/.ssh/`, `/etc/ssl/private/` 等へのアクセスを避ける
- ログファイルの内容は通常の運用ログのみ（認証ログは含む可能性、`security-policy.md` 参照）

### T5.1: SSM SendCommand の対象インスタンス範囲

**脅威**: ClaudeInvestigator Permission Set は `ssm:SendCommand` を `arn:aws:ec2:*:*:instance/*` に対して許可しており、対象アカウント内の**全 EC2 インスタンス**に Document を実行できる。

**現状の対策**:
- 実行できる Document は `claude-investigate-*` プレフィックスのもののみ（readonly に限定）
- すべての Document は読み取り専用で、書き込み・変更操作は不可

**残るリスク**:
- 「全インスタンスに対して読み取りができる」状態。最小権限の原則からは外れる
- 検証・本番混在のアカウントだと、検証外のインスタンスにも実行可能

**より厳格にしたい場合の方針**（運用判断）:

`modules/sso-permission-set/policies/claude-investigator-ssm.json` の `SSMRunInvestigateDocuments` ステートメントに `aws:ResourceTag` 条件を追加し、特定タグ付きインスタンスのみに絞る:

```json
{
  "Resource": "arn:aws:ec2:*:*:instance/*",
  "Condition": {
    "StringEquals": { "aws:ResourceTag/ssm-fleet:investigatable": "true" }
  }
}
```

利用者は調査対象インスタンスに `ssm-fleet:investigatable=true` をタグ付けして opt-in する運用になる。タグ無しのインスタンスは調査不可になる代わり、誤実行・横展開リスクが減る。

採否はトレードオフ（運用負荷 vs セキュリティ）の判断。デフォルトは現状（全インスタンス許可）のままで、必要な環境だけポリシーをカスタマイズする想定。

### T6: 子アカウントへの不正アクセス

**脅威**: 委任管理アカウント経由で子アカウントの予期しないリソースが操作される。

**対策**:
- StackSet で配布する IAM ロールは SSM Document 実行のみに限定
- 信頼ポリシーは委任管理アカウントの root のみ
- 他リソース（EC2 設定変更、S3 操作等）への権限は含めない

### T7: SSM Document の改竄

**脅威**: 悪意ある利用者が Document を編集して破壊的操作を埋め込む。

**対策**:
- ライブラリ更新は git PR レビュー必須
- CI で文法・パターンチェック（CI ワークフロー）
- 命名規約 `claude-investigate-*` で安全な Document と stateful Document を IAM レベルで区別
- 利用者が Document を直接 AWS Console から編集することを推奨しない（git 経由のみ）

### T8: 監査ログの欠落

**脅威**: トラブル発生時に「誰が何をしたか」が追えない。

**対策**:
- セットアップ操作は `install-audit.log` に記録
- AWS 側は CloudTrail に通常通り記録
- Terraform state の変更は git history で追跡可能
- 両方の視点で相互検証可能（`docs/audit-trail.md`）

## 信頼するもの

このツールが「信頼している」前提:

- 利用者のローカル端末（Claude Code 動作環境）
- AWS の標準セキュリティ機能（IAM, KMS, CloudTrail 等）
- 利用者の AWS アカウント運用（適切な MFA, root 保護等）
- HashiCorp Terraform / Anthropic Claude Code の公式実装

## 信頼しないもの

- AWS の一時的なエラー → リトライで対処
- ネットワーク経路の中間者 → HTTPS で対策
- 利用者以外の第三者の介入 → IAM ポリシーで最小権限化

## レビューポイント（導入担当者向け）

1. `bootstrap/installer-policy.json` の権限が許容範囲か
2. `modules/sso-permission-set/policies/*.json` の運用権限が許容範囲か
3. `documents/` 配下に怪しい記述がないか（pre-commit + CI）
4. `.gitignore` がシークレットを除外しているか
5. terraform state バケットの暗号化・パブリックアクセスブロック設定
6. CloudTrail が有効か（このツール外の責務だが前提）

これらを定期レビューすることで、脅威モデルが現実から乖離していないか確認できる。
