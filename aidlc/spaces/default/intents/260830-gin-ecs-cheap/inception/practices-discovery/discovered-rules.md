# Discovered Rules

> このプロジェクトに明確に当てはまるハード制約のみを記載する。最小限かつ根拠のあるものに絞る。LEAD ドラフトに支援コントリビューションと人間インタビュー（Q1〜Q7 すべて確認済み）を統合した内容。

## Mandated

- ALWAYS GitHub Actions の AWS 認証は OIDC + 引き受け IAM ロールで行い、信頼ポリシーを当該リポジトリ/ブランチに絞る（デプロイロールは最小権限）。
- ALWAYS `gofmt`/`go vet`/`golangci-lint`、`terraform fmt`/`terraform validate`/`tflint`、`gitleaks` を CI のブロッキングゲートとして実行し、失敗時はマージをブロックする。
- ALWAYS ECR リポジトリで scan-on-push（Basic scanning・無料）を有効化する。
- ALWAYS 環境をエフェメラル（作成・破棄可能）に保ち、使い終わったら `terraform destroy` で落とせる状態を維持する。
- ALWAYS ECR のイメージをコミット SHA でタグ付けし、デプロイとロールバックがそのタグで再現できるようにする。
- ALWAYS 月額コストを最小（目標 ¥1000 未満）に保つ構成を優先し、常設・高コストなリソースを既定にしない。

## Forbidden

- NEVER 長期 AWS アクセスキーを GitHub Secrets に保存する（OIDC + IAM ロール引き受けで認証する）。
- NEVER AWS の認証情報や秘密情報を含む Terraform state をリポジトリにコミットする（秘密も tfvars に書かず SSM 等で扱う）。
- NEVER `latest` タグに依存して ECS にデプロイする（不変のコミット SHA タグを使う）。
- NEVER 常設の production 環境や長命な `develop`/`release` ブランチを前提にする（トランクベース＋エフェメラル運用を守る）。

<!-- Confirmed by human (summary-confirmation: Looks correct). -->
