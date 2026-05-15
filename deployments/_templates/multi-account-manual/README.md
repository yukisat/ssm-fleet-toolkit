# Deployment Template: multi-account-manual

AWS Organizations を使わずに、複数アカウントへ Document を共有するテンプレート。

## 想定シナリオ

- Organizations 未導入だが複数 AWS アカウントを運用している
- 委任管理アカウントから手動指定したアカウントに Document を共有したい

## 概要

`shared_account_ids` 変数にアカウント ID を列挙する以外は `multi-account-org` とほぼ同じ。
StackSets 利用は前提から外れるため、子アカウント側の IAM ロールは別途手動で配布する必要がある。

詳細実装は後続で整備（雛形のみ提供）。
