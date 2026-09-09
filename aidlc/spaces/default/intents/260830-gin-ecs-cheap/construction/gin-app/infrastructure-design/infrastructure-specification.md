# Infrastructure Specification — gin-app（ECS on AWS, 最安・使い捨て）

このユニットのインフラは、Gin アプリを ECS で動かすための全体トポロジ（VPC/ECS/ECR/RDS/IAM）を含む。Terraform で `apply`/`destroy` する単一構成。リージョンは `ap-northeast-1`。

## Deployment

| Facet | Choice | Rationale |
|-------|--------|-----------|
| Compute model | ECS on **Fargate**、最小サイズ `256 CPU (0.25 vCPU) / 512 MB` | サーバー管理不要・最小課金単位 [NFR1.3] |
| 起動タイプの補足 | Bolt1 は on-demand Fargate、desired count = 1 | まず確実に動かす。Spot は将来検討（中断リスク回避） |
| Networking topology | 新規 VPC + **パブリックサブネット**（2AZ）、Internet Gateway。**NAT Gateway なし** | NAT は高コスト。タスクは publicIP 直付けで egress/ingress [FR3.2][FR3.3] |
| Public access | ECS タスクに `assign_public_ip = true`、SG で 80(or 8080)/tcp を許可。**ALB なし** | ALB 課金を回避、最安 [FR3.2] |
| ECR pull 経路 | パブリックサブネット + publicIP 経由で ECR に到達（NAT不要） | NATなし構成の pull 経路 [OQ2 解決] |
| Storage strategy | 永続ストレージなし（Bolt1）。Bolt2 で RDS 追加 | 最小構成 |
| Environments | 単一のエフェメラル環境。dev/stg/prod の常設分離なし | 使い捨て運用 [NFR2] |
| IaC approach | Terraform、`main.tf`/`variables.tf`/`outputs.tf`/`versions.tf` 分割、state はローカル | team-practices [C4] |
| Secrets | SSM Parameter Store（Bolt2 の DB 認証情報用）、ECS タスクに `secrets` で注入 | 秘密の非ハードコード [NFR3.1] |

## Infrastructure Services

| Service | Role | Configuration | Notes |
|---------|------|---------------|-------|
| ECR repository | container registry | scan-on-push (Basic) 有効、SHAタグ運用、`force_delete=true`（destroyでイメージごと削除） | [FR2.2][NFR3] destroy時に残さない |
| ECS cluster | orchestration | Fargate capacity providers | 最小 |
| ECS service + task definition | compute | 0.25vCPU/0.5GB、desired=1、publicIP付与 | [FR3.1] |
| CloudWatch Logs | logging | ロググループ、retention 1〜3日（短期・低コスト） | [NFR4.1] |
| IAM: ECS task execution role | ECR pull + logs + SSM 読み取り | 最小権限 | |
| IAM: ECS task role | アプリ実行時のAWS権限（最小、当面ほぼ不要） | 最小権限 | |
| IAM: GitHub Actions OIDC role | CI/CDがassume | OIDC provider + 信頼ポリシーを repo/branch 限定、ECR push/ECS deploy 権限 | [FR5.2][project.md Mandated] |
| RDS for MySQL（**Bolt2**） | database | `db.t4g.micro`、Single-AZ、最小ストレージ(20GB gp3)、`skip_final_snapshot=true`、publicly_accessible=false、SGでECSタスクからのみ3306許可 | [FR4.1][FR4.2] Bolt2で追加 |
| SSM Parameter Store（Bolt2） | secrets | DB接続情報（SecureString）、無料枠の標準パラメータ | [NFR3.1] |

## Shared Infrastructure

| Shared Resource | Owner Unit | Consumer Units | Access Boundary |
|-----------------|------------|----------------|-----------------|
| VPC / サブネット / SG | terraform-infra (U2) | gin-app タスク, RDS | 同一VPC内、SGで最小限に制限 |
| ECR リポジトリ | terraform-infra (U2) | cicd-pipeline (push), ECS (pull) | OIDCロール/タスク実行ロール |
| OIDC IAMロール | terraform-infra (U2) | cicd-pipeline (assume) | repo/branch 限定信頼ポリシー |

> 注: U1(gin-app) の infra 設計だが、単一 `terraform apply` 構成のため全体トポロジをここで定義。実装（Terraformコード）は U2(terraform-infra) が担う。

<!-- confirmed -->

