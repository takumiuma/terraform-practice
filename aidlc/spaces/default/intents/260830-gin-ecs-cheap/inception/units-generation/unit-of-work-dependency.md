# Unit of Work — Dependency DAG

このアーティファクトはトポロジ（何が何に依存し得るか）のみを記述する。実装順序・クリティカルパスは Delivery Planning (2.9) が決定する。

## 依存関係（有向辺: "A depends on B"）

- **U1 gin-app** → 依存なし（独立して開発・ユニットテスト可能）
- **U2 terraform-infra** → U1 に依存（ECS タスク定義がアプリのコンテナイメージを参照）
- **U3 cicd-pipeline** → U1, U2 に依存（アプリをビルドし、インフラの ECR/ECS/OIDCロールへデプロイ）

## 統合ポイント

- **U1 ↔ U2:** コンテナイメージ（ECR の image URI + SHA タグ）と、実行時の環境変数/SSM パラメータ（DB接続情報、ポート等）。
- **U1 ↔ U2 (RDS):** アプリは MySQL 接続文字列を環境変数/SSM 経由で受け取り、GORM で接続。
- **U2 ↔ U3:** ECR リポジトリ URI、ECS クラスター/サービス名、GitHub Actions が引き受ける IAM ロール ARN。
- **U3 → 実行:** OIDC でロールを引き受け、ビルド済みイメージを ECR に push、ECS サービスを更新、`/healthz` スモーク。

## 並行開発の機会

- U1（アプリ）は U2/U3 と独立に着手・ユニットテスト可能。
- U2（インフラ）の ECR/VPC/RDS 等の大半は U1 のアプリ完成を待たずに記述できる（ECS タスク定義のイメージ参照のみ U1 のイメージが必要）。
- したがって U1 と U2 の大部分は並行で進められる。U3 は U1・U2 の成果物が揃ってから。

## Machine-readable edge block

```yaml
units:
  - name: gin-app
    kind: service
    depends_on: []
  - name: terraform-infra
    kind: service
    depends_on: [gin-app]
  - name: cicd-pipeline
    kind: packaging
    depends_on: [gin-app, terraform-infra]
```
