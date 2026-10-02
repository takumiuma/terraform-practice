# Unit of Work — Gin on ECS (Cheapest, Terraform)

分解方針: 成果物の種類で3つの Unit に分割（粗め）。単独・学習・使い捨て前提のため最小構成。

## Unit 一覧

| Unit ID | Directory | Name | Kind | 複雑度 |
|---------|-----------|------|------|--------|
| U1 | u1-gin-app | gin-app | service | M |
| U2 | u2-terraform-infra | terraform-infra | service | L |
| U3 | u3-cicd-pipeline | cicd-pipeline | packaging | S |

## U1: gin-app (service, M)

- **責務:** Gin (Go) の HTTP サーバー本体とコンテナ化。
- **含むもの:**
  - `/healthz` エンドポイント（HTTP 200 を返す）[FR1.1]
  - MySQL に接続し、学習レベルの簡単な CRUD（または1行 read/write 確認）を行うエンドポイント [FR1.2]
  - 起動時に GORM の AutoMigrate でスキーマ（1テーブル程度）を初期化 [FR1.3]
  - `gin.SetMode(gin.ReleaseMode)`、エラーレスポンスに内部情報を含めない [FR1.4]
  - Dockerfile（distroless/scratch ベース、Go スタティックバイナリ）[FR2.1]
  - DB 接続情報は環境変数/SSM 経由で受け取る（ハードコードしない）[FR4.3]
- **デプロイモデル:** embedded（コンテナイメージとして U2 のインフラ上で動く）
- **依存:** なし（アプリ単体で開発・ユニットテスト可能）
- **実装メモ:** `cmd/`（エントリポイント）+ `internal/`（handler + logic）の最小レイアウト。`httptest` でハンドラのユニットテスト。

## U2: terraform-infra (service, L)

- **責務:** AWS インフラを Terraform で構築・破棄可能にする。
- **含むもの:**
  - VPC、パブリックサブネット（NAT Gateway なし）[FR3.2][FR3.3]
  - ECR リポジトリ（scan-on-push Basic 有効、SHA タグ運用）[FR2.2][NFR3]
  - ECS クラスター + Fargate タスク定義/サービス（最小サイズ 0.25vCPU/0.5GB、パブリックIP付与、ALBなし）[FR3.1][FR3.2]
  - RDS for MySQL（`db.t4g.micro`、Single-AZ、最小ストレージ、`skip_final_snapshot=true`）[FR4.1][FR4.2]
  - IAM/OIDC（GitHub Actions 用の引き受けロール、信頼ポリシーを repo/branch 限定、最小権限）[FR5.2]
  - SSM Parameter Store（DB 接続情報などの秘密）[FR4.3]
  - CloudWatch Logs（最小限のログ）[NFR4]
  - `main.tf`/`variables.tf`/`outputs.tf`/`versions.tf` に分割、バージョンピン留め [C4]
- **デプロイモデル:** standalone（`terraform apply`/`destroy` の対象）
- **依存:** U1（ECS タスク定義がアプリのコンテナイメージを参照する。ECRリポジトリ自体は独立に作成可能だが、意味のある稼働には U1 のイメージが必要）
- **実装メモ:** state はローカル、コミットしない。全リソースが destroy で残存課金なく消えること。RDS が月1000円を圧迫する場合は DynamoDB フォールバックを検討 [FR4.4][OQ1]。

## U3: cicd-pipeline (packaging, S)

- **責務:** GitHub → GitHub Actions → ECR → ECS のビルド・デプロイパイプライン。
- **含むもの:**
  - GitHub Actions ワークフロー（`.github/workflows/`）[FR5.1]
  - CI ゲート: `gofmt`/`go vet`/`golangci-lint`、`terraform fmt`/`validate`/`tflint`、`gitleaks`（失敗でブロック）[C3]
  - Go ビルド/テスト → Docker イメージビルド → ECR push（SHAタグ）→ ECS デプロイ [FR5.1]
  - OIDC 認証（`aws-actions/configure-aws-credentials`、長期キーなし）[FR5.2]
  - サードパーティ Action は SHA ピン留め [FR5.3]
  - デプロイ後 `/healthz` スモーク（200、`curl --fail`、リトライ）[FR6.1][FR6.2]
- **デプロイモデル:** embedded（リポジトリ内のワークフロー定義）
- **依存:** U1（アプリをビルド）、U2（ECR/ECS/OIDCロールへデプロイ）
- **実装メモ:** create→smoke→destroy の完全自動化は当面しない（手動運用）。ワークフローはビルド＋デプロイに集中。

## Assumptions & Open Questions

- RDS 最安構成の実測月額が1000円以内に収まるか。超える場合は U2 内で DynamoDB へ切り替え検討。[OQ1]
- NATなし構成での ECR イメージ取得経路（パブリック経路 or VPCエンドポイント）は U2 の設計で確定。[OQ2]

## Review

**Verdict:** READY
**Reviewer:** aidlc-architecture-reviewer-agent
**Date:** 2026-08-31T13:57:17Z
**Iteration:** 1

### Findings

| ID | Severity | Location | Finding | Required action | Status |
|---|---|---|---|---|---|
| R-01 | Minor | aidlc/spaces/default/intents/260830-gin-ecs-cheap/inception/units-generation/unit-of-work.md > U2 含むもの | FR3.4（`ap-northeast-1` 東京リージョン）は traceability.json（U2）と story-map（U2）で正しくカバーされているが、U2 の責務リストに [FR3.4] の明示的な引用がない。他の全 FR は行内タグで追跡できるため、この1件だけタグが欠落している。カバレッジ自体は traceability で担保されており阻害しない。 | U2 の「含むもの」にリージョン指定（`ap-northeast-1`）を [FR3.4] タグ付きで一行追記すると、成果物間のタグ一貫性が揃う。 | New |
| R-02 | Minor | aidlc/spaces/default/intents/260830-gin-ecs-cheap/inception/units-generation/unit-of-work.md > U2 依存 / unit-of-work-dependency.md 並行開発の機会 | U2→U1 の依存は「ECS タスク定義がアプリのコンテナイメージを参照する」ためと明記される一方、成果物自身が「ECR/VPC/RDS 等の大半は U1 を待たずに記述可能」と述べており、依存は U2 全体ではなく ECS タスク定義の1点に限定される。DAG のエッジ（unit粒度）としては正しく、循環もないが、開発者が「U2 全体が U1 完成を待つ」と誤読する余地がある。実装順序は 2.9 の判断であり本ステージのトポロジ記述としては妥当。 | 実害はない。任意で U2 の依存記述を「ECS タスク定義のイメージ参照に限る部分依存」と一語補足すると誤読を防げる。 | New |
| R-03 | Minor | aidlc/spaces/default/intents/260830-gin-ecs-cheap/inception/units-generation/unit-of-work.md > U1 デプロイモデル | U1 の kind は `service`（デプロイ可能な実行体）だが、デプロイモデルは「embedded（U2 のインフラ上で動く）」とされている。学習用途では実体（Gin サーバ＝service）と配備形態（イメージとして U2 が配置＝embedded）を分けた記述として一貫しており矛盾ではない。 | 対応不要。service/embedded の使い分けは意図通りと確認。 | New |

### Validation Tool Results

| Tool | Result | Interpretation |
|---|---|---|
| edge-block（手動検証） | PASS | 全 unit が一度だけ宣言、`depends_on` の全名（gin-app, terraform-infra）は宣言済み unit、自己依存なし、循環なし（gin-app → terraform-infra → cicd-pipeline の一方向）。kind は service/service/packaging で全て有効値。 |
| traceability（手動検証） | PASS | upstream_ids は requirements.md の全 FR（19件: FR1.1-1.4, FR2.1-2.2, FR3.1-3.4, FR4.1-4.4, FR5.1-5.3, FR6.1-6.2）と完全一致。全 coverage が OK、GAP なし。各 target（U1/U2/U3）は story-map の該当行に出現する Unit。 |
| story-map coverage（手動検証） | PASS | 全 FR が最低1 Unit に割当済み、全 Unit（U1/U2/U3）が担当 FR を保持。孤立要件・孤立 Unit なし。 |

### Summary

3 Unit（U1 gin-app / U2 terraform-infra / U3 cicd-pipeline）への分解は単独学習プロジェクトとして適切なサイズで、DAG は非循環かつ整合し、edge block は well-formed、19 の FR は traceability で漏れなくカバーされ、実装順序の指定は Delivery Planning に正しく委譲されている。指摘は全て Minor（FR3.4 のタグ欠落、U2 依存の部分性の誤読余地、service/embedded の記述）で承認を阻害しない。READY。
