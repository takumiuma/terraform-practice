# Units Generation — Decomposition Questions

作業を実装単位（Unit of Work）に分解します。小規模な学習プロジェクトなので、分解も軽量にします。

## Q1. Unit の分割方針

- A. 成果物の種類で3つに分ける: (1) Gin アプリ（Go＋Dockerfile）、(2) Terraform インフラ（VPC/ECS/ECR/RDS/IAM-OIDC）、(3) CI/CD（GitHub Actions）
- B. アプリとインフラの2つ（CI/CDはインフラに含める）
- C. 全部1つにまとめる（最小構成）
- X. Other (please specify)

[Answer]: A

## Q2. 粒度

- A. 粗め（上記の少数 Unit で十分。学習用途）
- B. 細かく分けたい（内容を記述）
- X. Other (please specify)

[Answer]: A

## Q3. 依存関係と並行開発

- A. Terraform インフラを土台に、アプリ→イメージ→ECS の順で依存。CI/CD は両者に依存。ただし walking skeleton（最小`/healthz`を1周）を最初に通す方針は Delivery Planning で順序決定
- B. 別の依存構造にしたい（内容を記述）
- X. Other (please specify)

[Answer]: A

## Q4. デプロイモデル

- A. 単一構成をまとめて `terraform apply`/`destroy` で扱う（使い捨て・単独）
- B. 別のモデル（内容を記述）
- X. Other (please specify)

[Answer]: A

## Consolidated Summary Confirmation

以下の分解で Unit 成果物を生成します。よろしいですか？

- **U1 gin-app (service, M):** Gin アプリ（`/healthz`、MySQL接続CRUD、GORM AutoMigrate）＋ Dockerfile。依存なし。
- **U2 terraform-infra (service, L):** Terraform 一式（VPC/パブリックサブネット、ECS Fargate、ECR、RDS for MySQL、IAM/OIDC、SSM）。U1 に依存。
- **U3 cicd-pipeline (packaging, S):** GitHub Actions（build/test/lint → ECR push → ECS デプロイ、OIDC）。U1・U2 に依存。
- **デプロイ:** 単一構成をまとめて `terraform apply`/`destroy`（使い捨て・単独）。
- 実装順序（walking skeleton を最初に通す等）は Delivery Planning で決定。

- Looks correct
- Request changes

[Answer]: Looks correct
