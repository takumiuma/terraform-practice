# チーム practices

> グリーンフィールド・単独開発・学習/実験目的のプロジェクト向け。`org.md` の各セクションを「推奨デフォルト」として参照し、Gin(Go) + Terraform + AWS ECS の低コスト・エフェメラル運用に合わせて調整している。LEAD ドラフトに3つの支援コントリビューション（quality / developer / devsecops）と人間インタビュー（Q1〜Q7 すべて確認済み）を統合した内容。

## Way of Working

トランクベース開発を採用する。すべての作業は短命なフィーチャーブランチ（1〜2日で解消）経由で `main` にマージする。単独開発かつ実験プロジェクトのため、長命ブランチや `develop`/`release` ブランチは持たない。単独作業では直接 `main` にコミットする運用も許容する。

`main` へは squash マージする。1つの作業単位が `main` 上の1コミットになり、線形で読みやすい履歴を保つ。Construction のワークツリーを使う場合も base/target はともに `main` とする。

環境は staging/production の常設多段構成を持たない。エフェメラルな create/destroy モデルで運用し、必要なときだけ環境を立てて使い終わったら破棄する。環境の差異はブランチではなく Terraform の変数やデプロイ設定で表現する。

GitHub Actions から AWS への認証は OIDC + IAM ロール引き受けで行い、長期アクセスキーを GitHub Secrets に置かない。引き受けるロールの信頼ポリシーは当該リポジトリ/ブランチに厳格に絞り、デプロイ権限は最小権限とする（詳細は ## Deployment）。

## Walking Skeleton

薄いエンドツーエンドのスライスを最初に作る。ここでの walking skeleton とは、Gin の最小ハンドラ（例: `/healthz` を返すだけ）を、GitHub Actions → ECR → ECS のパイプラインに一度通し、Terraform で最低コストの ECS 環境を立ち上げて実際に応答が返るところまでを最初に通すことを指す。

学習が主目的なので、この最初の一周（ビルド→push→デプロイ→動作確認→destroy）でパイプラインとインフラの接続を証明してから、実アプリのロジックを載せる。単独開発のため ceremony は最小限にし、スケルトンが通ったら以降は素早く反復する。

## Testing Posture

- **Methodology**: test-after
- **Ordering**: 各テスト対象レイヤ（Go のハンドラ/ロジック、Terraform の構成）を実装した後に、そのレイヤのテストを書いて実行する。
- Go は標準の `go test` を使い、ハンドラとビジネスロジックの happy-path を中心にユニットテストを書く。Gin ハンドラは `net/http/httptest` を用いてプロセスを起動せずにテストする。`/healthz` 以外のハンドラが増えた場合は、最低限のエラーパス（4xx を返す分岐）を1ケース目安で押さえておく。学習/実験プロジェクトのため厳格なカバレッジ率の下限は課さないが、無測定にはせず `go test -cover` でカバレッジを可視化する（レポート出力のみで、ゲートとしてブロックしない）。
- Terraform は `terraform validate` と `terraform plan` を CI で実行する。`validate` は構文・整合の静的検証だが、`terraform plan` は差分の可視化であって合否ゲートではない点に注意する。低コスト構成や命名を静的に守らせるため `tflint`（AWS ruleset）も CI で実行する。
- デプロイ後は ECS 上のエンドポイント `/healthz` に対するスモークテストで、新環境でサービスが健全に応答することを確認する。合否基準は「期待 HTTP ステータス 200」「タイムアウトとリトライを設定（例: 数秒間隔で数回リトライ）」「判定は `curl --fail` の終了コードで行う」とする。デプロイはスモークが通って初めて完了とみなす。
- エフェメラル運用のため、スモークは冪等・独立・タイムアウト付きとし、失敗時も必ず `terraform destroy` まで到達して環境を放置しない（コスト残置を防ぐ）ことを保証する。
- CI の必須ゲート（緑であること）は、Go のビルド＋ユニットテスト、`gofmt`/`go vet`/`golangci-lint`、`terraform fmt`/`validate`/`tflint`、`gitleaks` の各チェックとする（詳細と失敗時ブロックは ## Deployment と discovered-rules を参照）。
- 単独開発のためテストは軽量に保つが、パイプラインを壊す変更を検知できる最低限のセーフティネットは維持する。

## Deployment

`main` へのマージを契機に GitHub Actions が動く。パイプラインは Go のビルドとテスト → Docker イメージのビルド → ECR への push（イメージタグはコミット SHA を使い `latest` に依存しない）→ ECS へのデプロイ、の順で進む。

CI では以下を必須ゲートとし、失敗時はマージをブロックする。
- Go: `gofmt`（未整形は差分検知で非ゼロ終了）、`go vet`、`golangci-lint`（少なくとも `errcheck`/`staticcheck`/`govet` を有効化）。
- Terraform: `terraform fmt`、`terraform validate`、`tflint`。
- シークレットスキャン: `gitleaks`（誤コミット検知でブロック）。

GitHub Actions から AWS への認証は `aws-actions/configure-aws-credentials` を OIDC モード（`id-token: write` パーミッション + `role-to-assume`）で使い、`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` を GitHub Secrets に保存しない。信頼ポリシーの `sub` 条件は当該リポジトリ/ブランチ（例: `repo:<owner>/<repo>:ref:refs/heads/main`）に絞り、ワイルドカードを避ける。デプロイロールは ECR push + ECS デプロイ + 必要な Terraform 操作に絞る最小権限とする。サードパーティの GitHub Actions はメジャータグではなくコミット SHA でピン留めする。

ECR リポジトリは scan-on-push（Basic scanning・無料）を有効化する。イメージのベースは distroless か scratch など最小構成とし、Go のスタティックバイナリを載せて攻撃面とイメージサイズ（＝転送/ストレージコスト）を下げる。

インフラは Terraform で管理し、エフェメラルな create/destroy モデルで運用する。環境の create → smoke → destroy は当面 CI で自動化せず、手動運用とする（使うときに `terraform apply`、確認後に `terraform destroy`）。Terraform state はローカル state を用い（単独・使い捨て・最安優先）、リポジトリには絶対にコミットしない。秘密は `terraform.tfvars`/`*.auto.tfvars` に書かず、SSM Parameter Store（標準パラメータは無料枠）で扱う。使わないときは環境を落とし、月額コストを ¥1000 未満に抑えることを目標とする。常設の production 環境や多段昇格ゲートは持たない。

ロールバックは、直前のコミット SHA でタグ付けされた ECR イメージへ ECS サービスを戻すことで行う。単独開発かつ低リスクのため自動ロールバックの仕組みは持たず、スモーク失敗時は手動で切り戻す。

## Code Style

言語標準とプロジェクトの lint/format 設定に従う。フォーマッタ/リンタの設定はリポジトリルートに置き、CI で実行して失敗時はマージをブロックする。エージェントのコードスタイル提案は、まずプロジェクトのリンタ設定を確認し、リンタがカバーしていない場合にのみ適用する。

Go:
- フォーマットは `goimports` を既定とし（`gofmt` の整形に加えて import の整理まで行う）、CI では `gofmt -l` 相当で未整形をブロックする。`go vet` と `golangci-lint`（少なくとも `errcheck`/`staticcheck`/`govet`）を CI で実行する。
- 命名は Go idiomatic に従う。エクスポートは PascalCase、非エクスポートは camelCase。頭字語は大文字統一（`userID`・`HTTPServer`。`userId`/`HttpServer` にしない）、パッケージ名は短い小文字単数（`handler`。`handlers`/`Handler` にしない）、`Get`/`Set` 接頭辞は避ける。
- エラーハンドリングは、ハンドラ層（境界）でエラーを HTTP レスポンスへ一元的に変換し、それ以外の層は `fmt.Errorf("...: %w", err)` で context を付けてラップして返す。エラーを握り潰さない。
- ファイル構成は Go 標準レイアウトの最小構成として、`cmd/`（エントリポイント）と `internal/`（ハンドラ＋ロジック）程度に分ける。DI や Repository パターンは今回のスコープでは過剰なので導入しない（YAGNI）。
- `gin.SetMode(gin.ReleaseMode)`（本番相当モード）を用い、エラーレスポンスでスタックトレース等の内部情報を返さない。入力はバリデーションし、ログに秘密（トークン/認証情報）を出さない。

Terraform:
- `terraform fmt` でフォーマットし、`terraform validate` と `tflint` を CI で実行する。
- ファイルは `main.tf` / `variables.tf` / `outputs.tf` / `versions.tf` に分割し、`versions.tf` で `required_version` と provider の `required_providers` をバージョンピン留めする（エフェメラルな create/destroy を再現可能にするため）。
- リソース/変数名は snake_case を用い、「リソース種別＋役割」で意味のある名前（例: `aws_ecs_service.app`）にする。汎用的な名前（`example`・`instance`）は避ける。

秘密の扱い（共通）:
- 秘密はコードや tfvars にハードコードせず、SSM Parameter Store 等で扱う。
- サードパーティの GitHub Action はコミット SHA でピン留めする。

<!-- Confirmed by human (summary-confirmation: Looks correct). -->
