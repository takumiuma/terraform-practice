# Decision Log — Ideation Phase

| # | Decision | Rationale | Source |
|---|----------|-----------|--------|
| D-1 | ワークフローのスコープを custom `gin-ecs-cheapest-terraform` とする | Gin on ECS 最安 / Terraform という単一・明確なインフラ意図に必要な工程のみに絞るため（ideation framing の多くを省略） | 意図把握フェーズ |
| D-2 | 目的は学習・実験（練習）と位置づける | terraform-practice リポジトリでの AWS/Terraform/ECS 学習 | intent-statement [Q1][Q4] |
| D-3 | 運用モデルを使い捨て（create/destroy）とし、常時稼働は前提としない | コストを月1000円以内に抑える最優先方針 | intent-statement [Q9] |
| D-4 | ビルド・デプロイのパイプラインを GitHub → GitHub Actions → ECR → ECS とする | ユーザーが明示的に指定。Terraform 実装は ECR・ECS・OIDC/IAM ロールを含める | intent-statement [Q8] |
| D-5 | コスト目標を月1,000円以内とする（測定基準は後続で確定） | ユーザー指定のコスト上限 | intent-statement [Q9] |
| D-6 | 残存リソース・コスト水準・成果物実体の確定を後続フェーズへ委譲 | intent 段階では assumption として保持し、要件/NFR/インフラ設計で詰める | approval-handoff [Q2] |
| D-7 | Inception フェーズへ進む（Go） | スコープ明確・リスク管理可能・単独プロジェクト | approval-handoff [Q3] |
