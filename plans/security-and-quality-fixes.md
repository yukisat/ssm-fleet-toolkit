# セキュリティ・コード品質修正計画

## 背景

chaos-engineer + コードレビュー（再利用・品質・効率性の三観点）による分析で検出した問題を修正する。
対象は SSM Document、Terraform モジュール、スクリプト類。

---

## 修正項目一覧

### Priority 1: セキュリティ Critical（即時対応）

#### P1-1: journalctl Document の `eval` 撲滅

- **ファイル**: `documents/readonly/claude-investigate/os/journalctl/document.yaml:51-55`
- **問題**: `eval "$cmd"` でコマンドを実行。`allowedPattern` に依存した防御が唯一の砦であり、将来パターン変更で突破される構造的リスク。
- **修正**: 配列引数 or if-else で `journalctl` を直接実行。`eval` を削除。

```bash
# Before
cmd="journalctl --no-pager -n $LINES -p $PRIORITY --since \"$SINCE\""
if [ -n "$UNIT" ]; then
  cmd="$cmd -u $UNIT"
fi
eval "$cmd"

# After
if [ -n "$UNIT" ]; then
  journalctl --no-pager -n "$LINES" -p "$PRIORITY" --since "$SINCE" -u "$UNIT"
else
  journalctl --no-pager -n "$LINES" -p "$PRIORITY" --since "$SINCE"
fi
```

#### P1-2: IAM StackSet trust policy に Condition を追加（permission set 名を変数化）

- **ファイル**:
  - `modules/iam-stackset/main.tf:43-56`（Condition 追加）
  - `modules/iam-stackset/variables.tf`（`assumer_role_pattern` 変数追加）
  - `deployments/_template/main.tf`（モジュール呼び出しに変数を追加）
- **問題**: `Principal: { AWS: "arn:aws:iam::<DelegatedAdmin>:root" }` + Condition なし。委任管理アカウントの全 IAM エンティティが全 Organizations 配下の `ssm-fleet-investigate-role` を AssumeRole できる。
- **重要**: `iam-stackset` モジュールは `sso-permission-set` モジュールと独立しており、permission set 名（`var.permission_set_name`）を直接参照できない。Condition の ARN パターンをハードコードすると permission set 名をカスタムしたユーザーで AssumeRole が全失敗する。
- **修正**:
  1. `modules/iam-stackset/variables.tf` に `assumer_role_pattern` 変数を追加。
  2. CloudFormation テンプレートの Parameters に `AssumerRolePattern` を追加し、Condition で参照。
  3. `deployments/_template/main.tf` で permission_set_name から ARN パターンを組み立てて渡す。

```hcl
# modules/iam-stackset/variables.tf（追加）
variable "assumer_role_pattern" {
  description = "AssumeRole を許可する IAM ロール ARN のパターン（glob）。SSO の場合: aws-reserved/sso.amazonaws.com/AWSReservedSSO_<name>_*"
  type        = string
  default     = "aws-reserved/sso.amazonaws.com/AWSReservedSSO_ClaudeInvestigator_*"
}
```

```hcl
# deployments/_template/main.tf の iam-stackset 呼び出し（追加）
assumer_role_pattern = "aws-reserved/sso.amazonaws.com/AWSReservedSSO_${module.permission_set.permission_set_name}_*"
```

```json
// CloudFormation template の Condition（追加）
"Condition": {
  "ArnLike": {
    "aws:PrincipalArn": {
      "Fn::Sub": "arn:aws:iam::${DelegatedAdminAccountId}:role/${AssumerRolePattern}"
    }
  }
}
```

#### P1-3: `attach_aws_readonly` のデフォルトを `false` に変更（破壊的変更）

- **ファイル**: `modules/sso-permission-set/variables.tf:42-46`、`deployments/_template/terraform.tfvars.example`
- **問題**: `ReadOnlyAccess`（S3・RDS・Lambda コード・Secrets Manager メタデータ等を含む強力なポリシー）がデフォルト有効。他の権限変数（`include_athena = false`, `include_cloudwatch = false`）が opt-in なのに一貫性がない。
- **⚠️ 破壊的変更**: `default = true → false` の変更は、既存利用者が `terraform apply` した際に `ReadOnlyAccess` が即座に剥がれる。移行手順が必要。
- **修正**:
  1. `default = false` に変更し、description に「破壊的変更」の警告を追記。
  2. `deployments/_template/terraform.tfvars.example` に `attach_aws_readonly = true` をコメントで追加し、明示的な opt-in 方法を案内。
  3. PR description に **BREAKING CHANGE** として明記し、既存利用者向けの移行手順を記載する。

```hcl
# modules/sso-permission-set/variables.tf（変更後）
variable "attach_aws_readonly" {
  description = <<-EOT
    AWS managed policy ReadOnlyAccess を追加でアタッチするか。
    WARNING: この変数を false にすると既存環境から ReadOnlyAccess が削除される（破壊的変更）。
    明示的に true に設定している既存利用者への影響なし。
  EOT
  type    = bool
  default = false
}
```

---

### Priority 2: コード品質・安全性（高優先）

#### P2-1: `scripts/build-catalog.sh` の `REPO_ROOT` 未 export バグを修正

- **ファイル**: `scripts/build-catalog.sh:15, 41`
- **問題**: L15 で `REPO_ROOT` を計算するが `export` していない。Python ヒアドキュメントは子プロセスのため環境変数を継承できず、`os.environ.get("REPO_ROOT", ".")` が常に `"."` にフォールバック。別ディレクトリから実行すると `catalog.json` が空になる破壊的挙動。
- **修正**: `sys.argv[1]` で明示的に渡す（案B）。環境変数依存を排除。

```bash
# シェル側（変更なし、REPO_ROOT は計算済み）
python3 - "$REPO_ROOT" <<'PYEOF' > "$TMP"

# Python 側
import sys
repo_root = Path(sys.argv[1])
```

#### P2-2: template 直接埋め込みを変数経由に統一（3 ファイル）

- **ファイル**:
  - `documents/readonly/claude-investigate/nginx/error-log/document.yaml:38-42`
  - `documents/readonly/claude-investigate/os/system-messages/document.yaml:39-43`
  - `documents/readonly/claude-investigate/php/error-log/document.yaml:40-44`
- **問題**: `'{{ Filter }}'` と `{{ Lines }}` が変数代入なしに直接 shell コードに埋め込まれている。`$FILTER`, `$LINES` 変数経由に統一する（journalctl スタイルが正）。
- **変数宣言の順序**: 各ファイルでは `set -eu` 直後、`LOG="{{ LogPath }}"` と同じブロックに `LINES="{{ Lines }}"` および `FILTER="{{ Filter }}"` を追加する。既存の `LOG` 変数宣言と同レベルに並べるため重複は発生しない。

```bash
# Before
if [ -z '{{ Filter }}' ]; then
  tail -n {{ Lines }} "$LOG"
else
  tail -n {{ Lines }} "$LOG" | grep -- '{{ Filter }}' || echo "(該当行なし)"
fi

# After（各ファイルの冒頭変数宣言に追加）
LINES="{{ Lines }}"
FILTER="{{ Filter }}"
# ...
if [ -z "$FILTER" ]; then
  tail -n "$LINES" "$LOG"
else
  tail -n "$LINES" "$LOG" | grep -- "$FILTER" || echo "(該当行なし)"
fi
```

#### P2-3: `mysql/slow-log` の `{{ Lines }}` 直接埋め込みを修正

- **ファイル**: `documents/readonly/claude-investigate/mysql/slow-log/document.yaml:50`
- **問題**: `tail -n {{ Lines }}` が変数代入なしの直接埋め込み。他 Document との不統一。
- **修正**: 冒頭に `LINES="{{ Lines }}"` を追加し、`tail -n "$LINES"` に変更。

#### P2-4: `load-average` の awk 変数展開を `-v` 渡しに変更

- **ファイル**: `documents/readonly/claude-investigate/os/load-average/document.yaml:17-18`
- **問題**: `awk "BEGIN { print $load1 / $cores }"` でシェル変数を awk ソースに直接展開。構造的注入リスク + 0除算ガードなし + 2回のサブシェル起動。
- **修正**: `awk -v` で渡し、1回のサブシェルに集約。

```bash
# Before
"$(awk "BEGIN { print $load1 / $cores }")" \
"$(awk "BEGIN { print $load5 / $cores }")"

# After
read -r per1 per5 <<<"$(awk -v l1="$load1" -v l5="$load5" -v c="$cores" \
  'BEGIN { if (c>0) printf "%.2f %.2f\n", l1/c, l5/c; else print "null null" }')"
```

#### P2-5: `process-list` の JSON エスケープ欠落を修正

- **ファイル**: `documents/readonly/claude-investigate/os/process-list/document.yaml:33-37`
- **問題**: `printf "...\"command\":\"%s\"..."` で `comm` フィールドを直接埋め込み。ダブルクォートを含むプロセス名で JSON 破損。
- **修正**: awk 内で `comm` フィールドのダブルクォートとバックスラッシュをエスケープ。

```awk
{ gsub(/\\/, "\\\\", $7); gsub(/"/, "\\\"", $7); ... }
```

---

### Priority 3: マイナー改善（低優先）

#### P3-1: `pre-flight-check.sh` の IAM ロール確認コメントを削除

- **ファイル**: `bootstrap/pre-flight-check.sh:9`
- **問題**: コメントに「同名の IAM ロール」チェックと記載があるが実装がない。コメントと実装の乖離。
- **修正**: コメントから該当行を削除（bootstrap のスコープ外と明記）。

#### P3-2: `.gitignore` に `*.env` パターンを追加

- **ファイル**: `.gitignore:35-37`
- **問題**: `.env`、`.env.local` のみで `production.env` 等が漏れる。
- **修正**: `*.env`、`*.env.*` を追加。サンプルファイルは `!*.env.example` で許可。

---

## 実装方針

1. ブランチ: `fix/security-and-quality-issues`
2. 修正順: P1 → P2 → P3 の順に実施（セキュリティを先行）
3. 各 P1 項目は独立コミット（変更影響を分離）
4. Document 変更は SSM RegistrationError を引き起こさないことを `yamllint` で確認

## 除外（今回スコープ外）

以下は本 PR では対応しない。今後の改善として GitHub Issue で追跡する。

| 除外項目 | 理由 | 今後の扱い |
|---|---|---|
| `iam-stackset/main.tf` の `templatefile()` 化 | 大規模変更・別 PR 相当 | Issue 化して次の改善 PR で対応 |
| MySQL 3 接続の 1 回集約 | 効率改善。今回は安全性修正に集中 | Issue 化（効率改善 backlog） |
| Permission set の parallel API 呼び出し化 | 効率改善 | Issue 化（効率改善 backlog） |
| `Lines`/`TopN` の上限付き正規表現化 | Info レベル・影響小 | Issue 化（minor improvement backlog） |

---

## テスト方針

### 静的検証
- Terraform: `terraform validate`（validate のみ、apply なし）
- Shell script: `bash -n`（構文チェック）、`shellcheck`（静的解析）
- YAML: `yamllint`（Document yaml の検証）
- catalog.json: `scripts/build-catalog.sh --check`（生成確認）

### 異常系・エッジケース検証観点

| 修正項目 | 正常系 | 異常系・エッジケース |
|---|---|---|
| P1-1 journalctl eval | `$UNIT` あり/なし両方でコマンド組み立て確認 | `$SINCE` に空白含む場合（"1 hour ago"）を if-else で渡せること |
| P1-2 trust policy | Condition の JSON 構造が正しい | `DelegatedAdminAccountId` に不正値が入った場合は CloudFormation 側で拒否 |
| P1-3 attach_aws_readonly | `default = false` でプランに ReadOnlyAccess が含まれないこと | 既存環境が `true` を明示指定している場合に動作変更なし |
| P2-1 build-catalog.sh | リポジトリルート以外から実行しても正しい catalog を生成 | `sys.argv[1]` が渡されない場合の IndexError（呼び出し側は必ず渡すため対象外） |
| P2-2〜P2-3 変数統一 | `Filter` 空の場合はフィルタなし、非空の場合は grep | `Filter` にシングルクォートを含む値（allowedPattern で排除済み） |
| P2-4 load-average awk | `cores=0` のゼロ除算ガード | `/proc/loadavg` が浮動小数点以外の値を返すカーネルバグ環境（ガード不要） |
| P2-5 process-list | コマンド名にダブルクォートを含む場合に JSON が壊れないこと | バックスラッシュ含むコマンド名のエスケープ |

### AWS 実機検証の扱い
`terraform apply` / SSM Document の実際の登録は **sandbox 制約および組織要件**から CI では実施しない。
代わりに以下で品質を担保する:
- `terraform validate` で HCL の構文・型整合性を確認
- `yamllint` + `bash -n` で Document の構文を確認
- trust policy の Condition JSON は `jq` で構造検証
