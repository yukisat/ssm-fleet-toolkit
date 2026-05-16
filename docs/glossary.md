# 用語集

## AWS

- **SSM Document**: AWS Systems Manager で実行可能なコマンドセット。`Command` / `Automation` / `Session` 等の Type がある。本ツールは `Command` のみ使用
- **SSM SendCommand**: 指定 Document を対象インスタンスに送信して実行する API
- **SSM Online**: Systems Manager Agent が稼働中で AWS と通信できているインスタンスの状態
- **SSO Permission Set**: AWS IAM Identity Center（旧 AWS SSO）の権限テンプレート。アカウント × グループ単位で割り当てる
- **IdentityStore**: AWS Identity Center 内のユーザー・グループの管理機構
- **StackSet**: CloudFormation で複数アカウント・複数リージョンに同じスタックを配布する機能
- **service-managed StackSet**: AWS Organizations 統合された StackSet。trusted access の有効化が必要
- **trusted access**: AWS Organizations 配下のサービスを子アカウントに展開できるようにする組織レベル設定
- **委任管理アカウント**: 組織内で特定サービスの管理を任されたアカウント。本ツールでは Document を集約配信する役割

## このツール

- **`claude-investigate-*`**: 本ツールが提供する readonly な SSM Document の命名プレフィックス
- **`ssm-fleet-*`**: 本ツールが Terraform で作成する IAM・S3・DynamoDB・CloudFormation リソースの命名プレフィックス
- **インストーラ権限**: セットアップ時のみ必要な広い IAM 権限。完了後は削除可能
- **オペレータ権限**: 日常運用で必要な最小 IAM 権限。恒久的に保持
- **deployment**: 各組織が自分の AWS 環境にデプロイするために用意する Terraform 設定。`deployments/_template/` から派生
- **catalog.json**: Document / playbook のメタデータ集約 JSON。`scripts/build-catalog.sh` で `metadata.yaml` から自動生成

## 設計概念

- **readonly Document**: サーバーの状態を変更しない調査専用 Document
- **stateful Document**: サーバーの状態を変更する Document。本ツールでは原則受け入れない
- **playbook**: AWS API ベースの調査手順書。SSM Document との対称概念
- **claude_hints**: metadata.yaml のフィールド。Claude が結果を解釈するためのヒント
- **pre-flight check**: terraform apply 前の衝突検出（同名リソース等）
- **plan mode**: Claude Code 標準機能。実行前に全工程を提示して承認を得る
- **AI-native リポジトリ**: 利用者が Claude Code に依頼するだけで動作する前提の設計

## 安全性

- **scope creep**: 当初の readonly 限定から外れて stateful 操作を追加しようとする圧力。設計で構造的に防ぐ
- **defense in depth**: 単一の防御だけに頼らず、複数層で安全性を確保する（命名・state 分離・plan 確認・ロールバック等）
- **least privilege**: 最小権限。機能フラグで必要な権限だけを有効化
