# Unit of Work — Requirement Map

User Stories 工程はこのスコープでスキップのため、要件（FR）を Unit にマッピングする。

## FR → Unit マッピング

| FR ID | 要件 | Unit | Directory |
|-------|------|------|-----------|
| FR1.1 | `/healthz` が 200 を返す | U1 | u1-gin-app |
| FR1.2 | MySQL 接続の簡単な CRUD | U1 | u1-gin-app |
| FR1.3 | GORM AutoMigrate でスキーマ初期化 | U1 | u1-gin-app |
| FR1.4 | ReleaseMode、内部情報を返さない | U1 | u1-gin-app |
| FR2.1 | Docker イメージ（distroless/scratch） | U1 | u1-gin-app |
| FR2.2 | ECR へ push（SHAタグ） | U2, U3 | u2-terraform-infra, u3-cicd-pipeline |
| FR3.1 | ECS Fargate 最小サイズ | U2 | u2-terraform-infra |
| FR3.2 | パブリックサブネット直アクセス、ALBなし | U2 | u2-terraform-infra |
| FR3.3 | NAT Gateway なし | U2 | u2-terraform-infra |
| FR3.4 | 東京リージョン | U2 | u2-terraform-infra |
| FR4.1 | RDS for MySQL 最安構成 | U2 | u2-terraform-infra |
| FR4.2 | 使い捨て（skip_final_snapshot） | U2 | u2-terraform-infra |
| FR4.3 | DB接続情報を SSM で扱う | U1, U2 | u1-gin-app, u2-terraform-infra |
| FR4.4 | 1000円超なら DynamoDB フォールバック検討 | U2 | u2-terraform-infra |
| FR5.1 | GitHub Actions パイプライン | U3 | u3-cicd-pipeline |
| FR5.2 | OIDC + IAMロール認証 | U2, U3 | u2-terraform-infra, u3-cicd-pipeline |
| FR5.3 | サードパーティ Action の SHA ピン留め | U3 | u3-cicd-pipeline |
| FR6.1 | `/healthz` スモーク（200） | U3 | u3-cicd-pipeline |
| FR6.2 | スモーク通過でデプロイ完了 | U3 | u3-cicd-pipeline |

## カバレッジ検証

- すべての FR が少なくとも1つの Unit に割り当てられている。
- すべての Unit が担当 FR を持つ（U1: FR1.x/FR2.1/FR4.3、U2: FR2.2/FR3.x/FR4.x/FR5.2、U3: FR2.2/FR5.x/FR6.x）。

## Unit 内の実装順序メモ

- **U1:** `/healthz`（skeleton）→ MySQL 接続 → CRUD → テスト。
- **U2:** versions/provider → VPC/サブネット → ECR → IAM/OIDC → RDS → ECS。
- **U3:** CI（lint/test/build）→ ECR push → ECS デプロイ → スモーク。
