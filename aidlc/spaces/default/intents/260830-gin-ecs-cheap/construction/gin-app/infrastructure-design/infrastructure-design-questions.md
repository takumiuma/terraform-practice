# Infrastructure Design — gin-app

要件・practices でインフラ方針はほぼ確定しているため追加質問なし。最安・使い捨て構成として設計した。

## Consolidated Summary Confirmation

以下のインフラ構成で確定します（最安・使い捨て・東京リージョン）:

- **コンピュート:** ECS Fargate 最小サイズ（0.25 vCPU / 0.5GB）、desired=1、オートスケールなし
- **ネットワーク:** 新規VPC + パブリックサブネット(2AZ) + IGW。**NAT Gatewayなし**（高コスト回避）。タスクにパブリックIP直付け、SGで必要ポートのみ許可。**ALBなし**（課金回避）
- **ECR:** scan-on-push(Basic)、SHAタグ、destroy時にイメージごと削除
- **ログ:** CloudWatch Logs（retention 1〜3日）
- **IAM:** ECSタスク実行/タスクロール（最小権限）+ GitHub Actions用OIDCロール（repo/branch限定）
- **DB（Bolt2で追加）:** RDS MySQL `db.t4g.micro`/Single-AZ/最小ストレージ/`skip_final_snapshot=true`/非公開、SGでECSからのみ3306
- **秘密:** SSM Parameter Store
- **CI/CD:** Actions で lint/test/tf検証/build → OIDC認証 → ECR push(SHA) → ECSデプロイ → `/healthz`スモーク。手動 create/destroy
- **state:** ローカル、コミットしない

コスト観点: 常時起動する固定課金は「使っている間のFargate + (Bolt2の)RDS + わずかなECR/ログ」。ALB・NATを持たないことが最安の要。使わない間は destroy でほぼ0円。

- Looks correct
- Request changes

[Answer]: Looks correct
