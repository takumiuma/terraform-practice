# Initiative Brief — Gin on ECS (Cheapest, Terraform)

## Intent & Problem Statement

AWS・Terraform・ECS を実地で学ぶため、Gin (Go) の HTTP サーバーを Amazon ECS 上で最小コストで動かす方法を検証する。常時稼働の本番運用ではなく、必要なときだけ立ち上げ、動作確認し、終わったら破棄する使い捨ての実験環境を Terraform で再現可能に構築する。 [intent-statement]

## Scope Boundary

- **In scope:** Gin server の ECS 実行環境を Terraform で構築。ビルド・デプロイは GitHub → GitHub Actions → ECR → ECS のパイプラインを前提とし、Terraform 実装は ECR リポジトリ・ECS 関連リソース・GitHub Actions 用 OIDC/IAM ロールを含む。使い捨て運用（create/destroy）。 [intent-statement]
- **Out of scope:** 常時稼働の本番運用、複数環境（staging/prod）展開、外部エンドユーザー向け提供。 [intent-statement]

## Feasibility & Risk Highlights

- ECS on Terraform は確立されたパターンであり、技術的実現性は高い。
- 主なリスク（いずれも後続フェーズで対応）:
  - **残存リソース課金:** `destroy` 後も残り課金され得るリソース（ECR イメージ、Terraform state）の扱い。→ 要件・設計フェーズで確定。 [intent-statement]
  - **コスト水準未確定:** 「一番安く」の具体水準（Fargate Spot / 最小 vCPU・メモリ / NAT Gateway の要否 / リージョン）と月1000円以内の測定基準。→ NFR 要件・インフラ設計フェーズで確定。 [intent-statement]
  - **成果物の実体未確定:** GitHub リポジトリおよび Go アプリケーション（Gin サーバー）の実体・配置。→ 後続フェーズで確定。 [intent-statement]

## Team Plan

単独プロジェクト。意思決定・実装・スコープ判断はすべて開発者本人が行う。報告・共有要件なし。 [stakeholder-map]

## Success Criteria

- `terraform apply` で Gin サーバーが ECS 上で起動し、HTTP で応答が返る。 [intent-statement]
- `terraform destroy` で作成リソースが綺麗に破棄される。 [intent-statement]
- 一連の検証にかかる月額コストが 1,000 円以内。 [intent-statement]

## Go/No-Go Recommendation

**Go.** スコープは明確、リスクは後続フェーズで管理可能、単独プロジェクトのため合意形成の障害もない。Inception フェーズ（要件分析・作業単位化・設計）へ進む。 [approval-handoff-questions Q3]
