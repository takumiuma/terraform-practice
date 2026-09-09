# Intent Statement — Gin on ECS (Cheapest, Terraform)

## Problem Statement

AWS・Terraform・ECS を実地で学ぶため、Gin (Go) の HTTP サーバーを Amazon ECS 上で**最小コスト**で動かす方法を検証したい。常時稼働の本番運用ではなく、必要なときだけ立ち上げて動作確認し、終わったら破棄する使い捨ての実験環境を Terraform で再現可能に構築することが狙い。 [Q1] [Q4]

## Target Customer

利用者は開発者本人ひとり。学習・動作確認の用途で、外部エンドユーザーやチームメンバーへの提供は想定しない。 [Q2]

## Success Metrics

- `terraform apply` を実行すると Gin サーバーが ECS 上で起動し、HTTP でアクセスして応答が返る。 [Q3]
- `terraform destroy` を実行すると、作成したリソースが綺麗に破棄される。 [Q3]
- 一連の検証にかかる月額コストが 1,000 円以内に収まる。 [Q3] [Q9]

## Initiative Trigger

AWS/Terraform/ECS の学習・実験。加えて、ECS を最安構成で運用する方法（コスト最適化）の検証。 [Q4]

## Initial Scope Signal

- **Workflow-selected scope (`workflow-selected`)**: `gin-ecs-cheapest-terraform`。 [scope]
- **User-confirmed product boundary**: Gin server を ECS に最安構成で Terraform で立てる。ビルド・デプロイは **GitHub → GitHub Actions → ECR → ECS** のパイプラインを前提とし、Terraform 実装はこの構成を考慮する（ECR リポジトリ、ECS 関連リソース、GitHub Actions が AWS に認証するための OIDC/IAM ロールを含む）。運用は使い捨て（使うときだけ create、終わったら destroy）で、常時稼働は前提としない。 [Q8] [Q9]

## Assumptions & Open Questions

- ECR に置く Docker イメージや Terraform state など、`destroy` 後も残存し課金され得るリソースの扱い（destroy で ECR も消すか、state をローカルに置くか S3 に置くか等）は、後続の要件・設計フェーズで確定する。 [assumption]
- 「一番安く」の具体的なコスト水準（Fargate Spot / 最小 vCPU・メモリ / NAT Gateway の要否 / リージョン選択など）は、NFR 要件・インフラ設計フェーズで詰める。 [assumption]
- GitHub リポジトリおよび Go アプリケーション（Gin サーバー）の実体・配置は、後続フェーズで確定する。 [assumption]

## Review

**Verdict:** READY
**Reviewer:** aidlc-product-lead-agent
**Date:** 2026-08-30T14:33:56Z
**Iteration:** 1
**Request Challenge:** review:2a328e9ee5d345d0ccfef186ec723068

### Findings

| ID | Severity | Location | Finding | Required action | Status |
|---|---|---|---|---|---|
| R-01 | Major | aidlc/spaces/default/intents/260830-gin-ecs-cheap/ideation/intent-capture/intent-statement.md > Success Metrics / Initial Scope Signal | intent-statement が [Q9] を引用していたが、Q9 の [Answer] タグが空だった。今回 Q9 の [Answer] は "A"（使い捨て運用・月1000円以内目標）で埋まっており、引用元が実在し確認済みとなった。 | 対応不要。修正を確認済み。 | Resolved |
| R-02 | Minor | aidlc/spaces/default/intents/260830-gin-ecs-cheap/ideation/intent-capture/intent-statement.md > Success Metrics（月額1,000円以内） | コスト指標に測定窓・基準（対象月の範囲、apply〜destroy の実稼働時間ベースか暦月ベースか、含めるリソース範囲）が明示されていない。intent-statement の Assumptions 第2項で後続の NFR/インフラ設計フェーズに委ねる旨は記録済み。 | 後続フェーズで「1,000円以内」の測定基準（計測窓・課金対象範囲）を確定する。intent-capture 段階では assumption として明記されており阻害要因ではない。 | Unresolved |
| R-03 | Minor | aidlc/spaces/default/intents/260830-gin-ecs-cheap/ideation/intent-capture/intent-statement.md > Initial Scope Signal（User-confirmed product boundary） | スコープシグナルに CI/CD 詳細（GitHub → GitHub Actions → ECR → ECS、OIDC/IAM ロール）が埋め込まれている。Q8 の [Answer] にトレース可能。 | 現状維持で可（Q8 で人間が明示的に境界へ含めた）。 | Accepted risk |
| R-04 | Minor | aidlc/spaces/default/intents/260830-gin-ecs-cheap/ideation/intent-capture/intent-statement.md > Initiative Trigger | 「コスト最適化の検証」を trigger として事実提示しているが、これは Q4 の未選択肢 B の文言に相当する。Q4 の [Answer] は A（AWS/Terraform/ECS の学習・実験）のみ。コスト最優先方針自体は Q9 でグラウンドされるが、trigger（なぜ今）としてのコスト最適化は確認済み回答に直接は裏付けられていない。 | trigger を Q4=A（学習・実験）に限定するか、コスト最適化検証を trigger として残すなら Q9 由来である旨を [Q9] タグで明示する。軽微でありゲートを阻害しない。 | New |

### Summary

R-01（Q9 の空回答）は解消済み。intent-statement / stakeholder-map は全項目が確認済み回答にグラウンドされ、開発者が要件フェーズに着手できる状態。残る指摘は測定基準の後続確定（R-02）と trigger の軽微なグラウンディング（R-04）で、いずれも承認を阻害しない。
