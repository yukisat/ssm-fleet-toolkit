# レビュー依頼テンプレート

このリポジトリを別の Claude Code セッション、Gemini、人間のレビュアーに依頼するときに使うテンプレート。

## レビュア向けの導入文（このまま渡してよい）

---

このリポジトリ (ssm-fleet-toolkit) は、AWS SSM Document と Claude Code スキルを汎用ライブラリとして配布する OSS 候補のテンプレートです。
以下の観点で多面的なレビューをお願いします。各項目で「OK」または「問題: 〇〇 (場所: file:line)」「改善案: 〇〇」の形式で報告してください。

---

## レビュー観点

### 1. セキュリティ（最重要）

#### 1-1. シークレット / 機密情報の混入

- [ ] AWS アクセスキー・シークレットキーが含まれていないか（パターン: `AKIA[0-9A-Z]{16}`、`aws_secret_access_key`）
- [ ] API キー・トークン・JWT・パスワードがハードコードされていないか
- [ ] SSH 秘密鍵 (`-----BEGIN ...PRIVATE KEY-----`) や証明書ファイルがないか
- [ ] 顧客固有情報（社名・顧客名・社内ドメイン・社内 URL・特定アカウント ID）が混入していないか
- [ ] `.gitignore` でシークレット系（`.env`, `*.pem`, `*.key`, `*.tfvars`）が除外されているか
- [ ] git log の過去コミットに上記が含まれていないか（`git log -p` でチェック）

#### 1-2. IAM 権限の妥当性

- [ ] `bootstrap/installer-policy.json` の権限が必要最小限か（過剰権限の有無）
- [ ] `modules/sso-permission-set/policies/*.json` の各機能ポリシーが readonly に徹しているか
- [ ] Resource 指定で `*` を使っている箇所が妥当か（API 仕様上やむを得ない場合のみ）
- [ ] StackSet 経由で配布される IAM ロール（`modules/iam-stackset/`）の信頼ポリシーが適切か
- [ ] 書き込み権限が意図せず含まれていないか（CreateRole / PutObject / Delete 系）

#### 1-3. インジェクション・コマンド実行リスク

- [ ] SSM Document の `runCommand` でユーザーパラメータを sanitize なしで eval / shell 展開していないか
- [ ] パラメータ展開 `{{ Foo }}` のコンテキスト（変数代入時のクォート漏れ）に脆弱性がないか
- [ ] `bootstrap/*.sh` で `eval "$*"` のような危険パターンがないか（必要な場合は意図と緩和策を明示）
- [ ] heredoc 内の変数展開が想定通りか

#### 1-4. 既存環境への侵襲

- [ ] 命名プレフィックス（`ssm-fleet-*` / `claude-investigate-*`）が一貫しているか
- [ ] 既存リソースを参照する箇所が `data` source であり、`resource` で管理していないか
- [ ] Terraform state の物理分離（専用 S3 バケット）が前提になっているか
- [ ] rollback パスが提供され、ドキュメント化されているか (`docs/rollback.md`)
- [ ] pre-flight-check.sh で衝突検出ができているか

#### 1-5. 監査性

- [ ] 重要な操作が `install-audit.log` 等で記録される設計になっているか
- [ ] CloudTrail で追跡可能な操作のみ使っているか
- [ ] 異常時の停止条件（plan の destroy 検出、エラー時の即時停止）が明確か

#### 1-6. サプライチェーン

- [ ] Terraform プロバイダ・モジュールが公式ソース（`hashicorp/aws` 等）か
- [ ] 外部スクリプトを curl で取得して実行する箇所がないか
- [ ] GitHub Actions で使う action が公式 (`actions/*` / `hashicorp/*` 等) か、SHA pin の検討余地はないか

### 2. 汎用性

#### 2-1. 顧客固有情報の混入

- [ ] 特定の組織名・社名がドキュメント・コメント・サンプルに混入していないか
- [ ] 12 桁の AWS アカウント ID が placeholder ではなく実値で残っていないか
- [ ] 社内ホスト名・FQDN が含まれていないか
- [ ] 担当者名・メールアドレスが含まれていないか
- [ ] 「自社固有のディレクトリ規約 (`/var/www/vhosts/...` 等)」がハードコードされていないか

#### 2-2. 環境多様性への対応

- [ ] 単一アカウント / Organizations / 手動マルチアカウント の 3 環境で動く設計か
- [ ] Document の `supported_os` が現実的な範囲をカバーしているか
- [ ] パス前提（`/etc/nginx/`, `/var/log/...`）がパラメータ化されているか、フォールバック探索があるか
- [ ] bash / zsh / POSIX shell の互換性が考慮されているか
- [ ] macOS / Linux 両方で bootstrap が動くか

### 3. AI-native 設計の妥当性

- [ ] ルート CLAUDE.md が短く保たれているか（経験則 200 行未満）
- [ ] サブディレクトリ CLAUDE.md / SKILL.md が編集対象ごとに置かれているか
- [ ] 利用者が「Claude Code に依頼するだけで導入完了」できる作りか
- [ ] スキル (.claude/skills/) の指示が具体的で曖昧でないか
- [ ] catalog.json と metadata.yaml の整合性が取れているか（`scripts/build-catalog.sh --check` で確認可能）
- [ ] `claude_hints` フィールドが結果解釈に役立つ内容か

### 4. Document / playbook の品質

- [ ] 全 Document が readonly か（stateful な動作がないか）
- [ ] 出力が JSON 形式で機械可読か
- [ ] エラーハンドリング（`set -eu`, 明確な exit code）が一貫しているか
- [ ] 命名規約 `claude-investigate-*` が守られているか
- [ ] 危険コマンド（rm, chmod, kill, systemctl reload 等）が含まれていないか

### 5. ドキュメント・運用

- [ ] README が利用者の導線として機能しているか
- [ ] `docs/required-permissions.md` が必要権限を完全に開示しているか
- [ ] `docs/what-this-does-not-do.md` がスコープ外を明示しているか
- [ ] `docs/coexistence.md` が既存環境との非破壊性を説明しているか
- [ ] `docs/rollback.md` で完全撤退手順が示されているか
- [ ] CHANGELOG が更新されているか

### 6. CI / 品質保証

- [ ] CI ワークフロー (`.github/workflows/checks.yml`) が機能しているか
- [ ] terraform fmt / validate / shellcheck / yaml syntax / catalog --check が網羅されているか
- [ ] CI が無料枠で完結する設計か（並列ジョブ制限・timeout 設定）

### 7. 改善提案

- 設計上の見落とし、追加すべき安全弁
- Document / playbook の追加候補（カテゴリ別）
- OSS 公開に向けて不足しているもの（LICENSE / CODE_OF_CONDUCT / SECURITY 等は確認済みの前提）

## 報告フォーマット

```
## レビュー結果

### Critical (即修正必要)
- [問題] xxx (file:line)
  - 詳細: ...
  - 修正案: ...

### High (公開前に修正推奨)
- ...

### Medium (改善余地)
- ...

### Low / 改善提案
- ...

### 良かった点（参考まで）
- ...
```

## レビュー実行コマンドの例

```bash
# シークレット検出
grep -rEn 'AKIA[0-9A-Z]{16}|aws_secret_access_key' .
grep -rEn 'BEGIN.*(PRIVATE|RSA|EC) KEY' .
grep -rEn '[0-9]{12}' . --include="*.md" --include="*.tf" --include="*.json" \
  | grep -vE '<placeholder>|111111111111|123456789012|999999999999'

# 顧客固有情報の検出（具体的なキーワードはレビュアの環境に依存）
grep -rEn '<your-org-keywords-here>' .

# 危険コマンドの検出（Document 内）
grep -rEn 'rm |chmod |systemctl (reload|restart|stop)|kill ' documents/

# Terraform 検証
terraform fmt -recursive -check
for m in modules/*/; do
  terraform -chdir="$m" init -backend=false -input=false
  terraform -chdir="$m" validate
done

# Shell スクリプト検証
shellcheck bootstrap/*.sh scripts/*.sh

# YAML 構文
python3 -c 'import glob,yaml; [yaml.safe_load(open(f)) for f in glob.glob("**/*.yaml", recursive=True)]'

# catalog 整合性
./scripts/build-catalog.sh --check
```
