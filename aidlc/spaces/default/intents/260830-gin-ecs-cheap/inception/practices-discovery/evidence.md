# Evidence

> pipeline-deploy リードの調査・推論、3つの支援コントリビューションが検査・推論した内容、人間インタビューの決定（Q1〜Q7）、および後続フェーズへ繰り延べた不確実性を記録する。

## LEAD（pipeline-deploy）が調査・推論したもの

- `aidlc/spaces/default/intents/260830-gin-ecs-cheap/aidlc-state.md` 経由のプロジェクト種別: グリーンフィールド・単独開発・学習/実験目的。
- `aidlc/spaces/default/memory/org.md` の5セクション（Way of Working / Walking Skeleton / Testing Posture / Deployment / Code Style）を推奨デフォルトとして参照。
- pipeline-deploy 知識ベース: `branching-strategies.md`（トランクベースを既定と選択）、`cicd-patterns.md`（CI ステージ順・ECR は不変タグ）、`deployment-strategies.md`（ロールバックはタグ済みイメージへ戻す）。
- ディスパッチブリーフのプロジェクト意図: Gin(Go) HTTP サーバ、AWS ECS 最低コスト（月額 ¥1000 未満）、Terraform 実装、エフェメラルな create/destroy 運用、GitHub → GitHub Actions → ECR → ECS のビルド&デプロイパイプライン。
- 推論: Way of Working はトランクベース＋squash マージをそのまま採用。Walking Skeleton は `/healthz` の薄いスライスを最初に一周。Testing Posture は `test-after`・カバレッジ下限なし・デプロイ後スモーク。Deployment は常設環境なし・コスト最小・SHA タグ済みイメージへ手動ロールバック。Code Style は Go/Terraform のフォーマッタ・リンタに委譲。

## 支援コントリビューションが検査・推論したもの

- **aidlc-quality-agent**: `## Testing Posture` を QA 観点で検証し「適正サイズ」と評価。テストピラミッド＋Minimal 戦略に整合。補強として、`go test -cover` による可視化（ゲートなし）、Gin ハンドラの `net/http/httptest`、エラーパス1ケース目安、`terraform plan` は差分可視化で合否ゲートではない旨の注記、スモークの合否基準（対象エンドポイント・期待ステータス・タイムアウト/リトライ・`curl --fail`）、失敗時も destroy に到達しコスト残置を防ぐこと、CI 必須ゲートの単一参照点化を提示。未解決点としてカバレッジ扱い・リンタ必須/任意・スモーク合否基準・スモーク自動化範囲・失敗時のコスト保護を挙げた。
- **aidlc-developer-agent**: Code Style / Way of Working を developer 観点で評価し妥当と判断。補強として、`goimports` 既定化と `gofmt -l` ブロック、`golangci-lint`（`errcheck`/`staticcheck`/`govet`）の必須化検討、Go idiom 命名（頭字語大文字統一・パッケージ名は小文字単数・`Get`/`Set` 回避）、`%w` ラップ＋ハンドラ境界での error→HTTP 変換、レイヤ構成（`cmd/`＋`internal/`、DI/Repository は YAGNI）、Terraform のファイル分割（`main.tf`/`variables.tf`/`outputs.tf`/`versions.tf`）＋バージョンピン留め、`tflint` 位置づけ、リソース命名（種別＋役割）を提示。
- **aidlc-devsecops-agent**: 5セクションと discovered-rules を DevSecOps 観点でレビュー。重い商用ツールは不要と判断しつつ、コスト無関係の必須事項として、GitHub Actions → AWS は OIDC/IAM ロール一択（長期キー禁止・信頼ポリシーをリポジトリ/ブランチに厳格化・最小権限）、Terraform state の秘密取り扱い（コミット禁止・秘密は SSM）、`gitleaks` によるシークレットスキャン（無料・ブロック）、ECR scan-on-push（Basic・無料）、distroless/scratch 最小ベースイメージ、GitHub Actions の SHA ピン留め、HTTPS 終端、`gin.ReleaseMode`、ログに秘密を出さないことを提示。DAST は本規模では過剰でスモークで十分と判断。

## 人間インタビューの決定（すべて確認済み）

- **Q1 = A**: トランクベース・短命ブランチ → `main` へ squash マージ。単独のため直接 `main` も可。
- **Q2 = A**: 実ロジックの前に walking skeleton（最小 `/healthz` の Gin を GitHub Actions→ECR→ECS に通し、Terraform で最小 ECS 環境を立てて応答を確認）を先に作る。
- **Q3 = A**: test-after。Go は `go test` で happy-path 中心、Terraform は `validate`/`plan`、デプロイ後 `/healthz` スモーク。厳格なカバレッジ下限なし。
- **Q4 = A**: lint を CI のブロッキングゲートとして必須化。`gofmt`/`go vet`/`golangci-lint`（少なくとも errcheck/staticcheck/govet）、`terraform fmt`/`validate`（＋`tflint`）、`gitleaks`。失敗はマージをブロック。
- **Q5 = A**: GitHub Actions は OIDC + 引き受け IAM ロールで AWS 認証（GitHub Secrets に長期キーを置かない）。信頼ポリシーを当該リポジトリ/ブランチに限定、最小権限デプロイロール。
- **Q6 = A**: Terraform state はローカル（単独・使い捨て・最安）。state はコミットしない。
- **Q7 = A**: create → smoke → destroy は手動運用（必要時 apply、確認後 destroy）。当面 CI 自動化はしない。

## 後続フェーズへ繰り延べた不確実性

- ECS の起動タイプ（Fargate vs EC2/Spot）や最小構成のサイジング（コストに直結）→ NFR & インフラ設計フェーズで決定。
- 引き受ける OIDC/IAM ロールの具体的な信頼ポリシーと権限境界の詳細 → インフラ設計フェーズで決定。

<!-- Confirmed by human (summary-confirmation: Looks correct). -->
