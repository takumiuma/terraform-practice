# Delivery Planning — Questions

実装の進め方（Bolt = 1回の実装パスで、動くものが1つ仕上がる単位）の順序を決めます。practices で「walking skeleton を最初に通す」方針が確定済みなので、それを軸にした案を提案します。

## Q1. 最初に何を作りますか？

- A. 薄いエンドツーエンドのスライス（walking skeleton）を最初に作る。最小の`/healthz` Gin を GitHub Actions→ECR→ECS に通し、Terraform で最小 ECS 環境を立てて応答が返るところまでを最初に1周（DB はこの後）。パイプラインとインフラの接続を先に証明する
- B. リスクの高い部分（RDS/コスト）から先に
- C. その他（内容を記述）
- X. Other (please specify)

[Answer]: A

## Q2. Bolt の分け方（案）

- A. Bolt1: walking skeleton（`/healthz` のみ + 最小インフラ + CI/CDパイプライン疎通）→ Bolt2: MySQL(RDS) と DB接続CRUD を追加。2つの Bolt で段階的に
- B. 全部まとめて1つの Bolt で作る
- C. その他（内容を記述）
- X. Other (please specify)

[Answer]: A

## Q3. スコアリングモデル（WSJF など）を使いますか？

- A. 使わない。小規模・単独なので walking-skeleton-first の順序で十分
- B. 使う（重み付けを記述）
- X. Other (please specify)

[Answer]: A

## Q4. Bolt は並行実行できますか？

- A. 直列（単独開発なので1つずつ）
- B. 並行
- X. Other (please specify)

[Answer]: A

## Q5. 外部依存で止まりそうなものはありますか？

- A. なし（GitHub リポジトリと AWS アカウントは自分で用意済み/用意する。外部チームの承認待ち等はなし）
- B. ある（内容を記述）
- X. Other (please specify)

[Answer]: A

## Q6. この構築で一番不安な点は？（早めに潰したいもの）

- A. コストが1000円を超えないか（特に RDS）。→ walking skeleton の後、RDS 追加時に実コストを確認
- B. パイプライン（OIDC 認証・ECS デプロイ）が通るか
- C. その他（内容を記述）
- X. Other (please specify)

[Answer]: A

## Q7. Construction の進め方（体制）

- A. このセッションで1つずつ作る（各ステージで私が確認を取りながら進める）。単独なのでこれで十分
- B. 複数チームでユニットを分担する（各チームが独立に承認）
- X. Other (please specify)

[Answer]: A

## Consolidated Summary Confirmation

以下の実装計画で成果物を生成し、Construction へ進みます。よろしいですか？

- **順序方針:** walking-skeleton-first（薄いE2Eスライスを最初に1周）。
- **Bolt1（walking skeleton）:** 最小 `/healthz` Gin + 最小 Terraform インフラ（VPC/ECS Fargate/ECR/IAM-OIDC）+ CI/CD パイプライン疎通。DoD: `apply`→`/healthz` が 200→`destroy` が通る。証明: パイプラインとインフラの接続。
- **Bolt2:** RDS(MySQL) と DB接続CRUD（GORM AutoMigrate）を追加。DoD: `apply`→CRUD動作→`destroy`。証明: DB込みでコスト1000円以内に収まるか。
- **スコアリング:** 使わない（skeleton-first で十分）。
- **並行実行:** 直列（単独）。
- **外部依存:** なし。
- **主リスク:** コスト（特にRDS）→ Bolt2 で実コスト確認。
- **Construction 体制:** このセッションで1つずつ（unit-major、solo、各ステージで確認）。

- Looks correct
- Request changes

[Answer]: Looks correct
