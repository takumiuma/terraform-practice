# Bolt Plan — Gin on ECS (Cheapest, Terraform)

> Bolt = 実装の1パスで、動くものが1つ仕上がる単位（ビルド → デプロイ → 動作確認まで）。walking skeleton = すべての層を貫く最小のエンドツーエンド版で、機能は後続の Bolt で足す。

順序方針: **walking-skeleton-first**。パイプラインとインフラの接続を最小構成で先に証明してから、DB とアプリロジックを載せる。直列実行（単独開発）。

## Bolt 1: Walking Skeleton（薄いE2Eスライス）

- **含む Unit:** U1 gin-app（`/healthz` のみ）、U2 terraform-infra（VPC/パブリックサブネット、ECR、ECS Fargate、IAM/OIDC、CloudWatch Logs。**RDS はまだ含めない**）、U3 cicd-pipeline（build/lint/test → ECR push → ECS デプロイ → スモーク）
- **walking-skeleton marker:** ✅ YES
- **証明する層:** GitHub → GitHub Actions（OIDC 認証）→ ECR（SHAタグ）→ ECS Fargate（パブリックIP直アクセス）→ `/healthz` 応答、の一連の接続。Terraform の `apply`/`destroy` サイクル。
- **Definition of Done:**
  - `terraform apply` で最小 ECS 環境が立ち上がる
  - `/healthz` に HTTP 200 が返る（`curl --fail`）
  - `terraform destroy` で残存課金なく破棄できる
  - CI（gofmt/go vet/golangci-lint、terraform fmt/validate/tflint、gitleaks）が緑
- **confidence hypothesis:** 「最安構成（ALBなし・NATなし・Fargate最小）で Gin が ECS 上で外部から応答し、パイプラインとインフラが接続し、使い捨てサイクルが成立する」ことを証明する。
- **expected demo:** `apply` → ブラウザ/curl で `/healthz` が 200 → `destroy`。

## Bolt 2: MySQL(RDS) + DB接続CRUD

- **含む Unit:** U1 gin-app（MySQL接続の CRUD エンドポイント + GORM AutoMigrate）、U2 terraform-infra（RDS for MySQL 最安構成 + SSM Parameter Store で接続情報）、U3 cicd-pipeline（変更なし、または DB マイグレーション考慮）
- **walking-skeleton marker:** ✗ NO
- **Definition of Done:**
  - `terraform apply` で RDS(MySQL) を含む環境が立ち上がる
  - Gin が RDS に接続し、GORM AutoMigrate でスキーマ初期化、簡単な CRUD（または1行 read/write）が動作
  - `terraform destroy` で RDS もスナップショットを残さず破棄
  - 実コストが月1000円以内に収まる見込みを確認（超えそうなら DynamoDB フォールバックを検討）
- **confidence hypothesis:** 「RDS を含めても使い捨て運用で月1000円以内に収まり、Gin から MySQL への接続・CRUD が成立する」ことを検証する。
- **expected demo:** `apply` → CRUD エンドポイントでデータを書いて読む → コスト確認 → `destroy`。

## 実装イテレーション

- Construction iteration: **unit-major**（skeleton を成すユニットを設計・実装して動かしてから次へ。早期に動くコードを得る）
- Construction staffing: **solo**（このセッションで1つずつ、各ステージで人間が確認）
- 分岐（base/target ブランチ）: `main`、squash マージ（team practices の Way of Working に従う）
