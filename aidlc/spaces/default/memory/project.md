# Project-Level Rules

> Project-specific specialisation and corrections. Loaded after `org.md` and
> `team.md` as strict-additive guidance; contradictions with broader policy
> are rejected. Populated by practices-discovery and the self-learning loop.
>
> Use sparingly: most teams don't need a project layer. Reach for it
> only when this specific project needs stable, durable guidance beyond the
> team practice (for example, package-specific release checks or an additional
> regression suite for a legacy component).

## Way of Working

<!-- Project-specific specialisation. Example: -->
<!-- This monorepo requires package-scoped branch names and a package owner -->
<!-- review in addition to the team's normal merge policy. -->

## Walking Skeleton

<!-- Project-specific specialisation. Example: -->
<!-- The walking skeleton must exercise the legacy service adapter as well -->
<!-- as the new service boundary. -->

## Testing Posture

<!-- Project-specific specialisation. -->

## Deployment

<!-- Project-specific specialisation. -->

## Code Style

<!-- Project-specific specialisation. -->

## Tech Stack

<!-- Technology choices locked for this project. -->

## Decided

<!-- Decisions made in earlier stages that should not be re-asked. -->
<!-- Format: DECIDED: [decision] (Stage [slug], [date]) -->

## Scope Overrides

<!-- Custom scope rules for this project. -->

## Forbidden

<!-- Populated by practices-discovery affirmation gate. -->
<!-- Format: NEVER [behavior] (affirmed [date]) -->
<!-- Example: NEVER throw exceptions across service layer boundaries (affirmed 2026-05-17) -->

- NEVER 長期 AWS アクセスキーを GitHub Secrets に保存する（OIDC + IAM ロール引き受けで認証する）。 (affirmed 2026-08-31)
- NEVER AWS の認証情報や秘密情報を含む Terraform state をリポジトリにコミットする（秘密も tfvars に書かず SSM 等で扱う）。 (affirmed 2026-08-31)
- NEVER `latest` タグに依存して ECS にデプロイする（不変のコミット SHA タグを使う）。 (affirmed 2026-08-31)
- NEVER 常設の production 環境や長命な `develop`/`release` ブランチを前提にする（トランクベース＋エフェメラル運用を守る）。 (affirmed 2026-08-31)
## Mandated

<!-- Populated by practices-discovery affirmation gate. -->
<!-- Format: ALWAYS [behavior] (affirmed [date]) -->
<!-- Example: ALWAYS use Result<T,E> for fallible operations in service layer (affirmed 2026-05-17) -->

- ALWAYS GitHub Actions の AWS 認証は OIDC + 引き受け IAM ロールで行い、信頼ポリシーを当該リポジトリ/ブランチに絞る（デプロイロールは最小権限）。 (affirmed 2026-08-31)
- ALWAYS `gofmt`/`go vet`/`golangci-lint`、`terraform fmt`/`terraform validate`/`tflint`、`gitleaks` を CI のブロッキングゲートとして実行し、失敗時はマージをブロックする。 (affirmed 2026-08-31)
- ALWAYS ECR リポジトリで scan-on-push（Basic scanning・無料）を有効化する。 (affirmed 2026-08-31)
- ALWAYS 環境をエフェメラル（作成・破棄可能）に保ち、使い終わったら `terraform destroy` で落とせる状態を維持する。 (affirmed 2026-08-31)
- ALWAYS ECR のイメージをコミット SHA でタグ付けし、デプロイとロールバックがそのタグで再現できるようにする。 (affirmed 2026-08-31)
- ALWAYS 月額コストを最小（目標 ¥1000 未満）に保つ構成を優先し、常設・高コストなリソースを既定にしない。 (affirmed 2026-08-31)
## Corrections

<!-- Project-specific corrections from human feedback. -->
<!-- Format: NEVER/ALWAYS [behavior] (learned [date]) -->

- ALWAYS このプロジェクトの会話・成果物は日本語で行う。 (learned 2026-09-05)
