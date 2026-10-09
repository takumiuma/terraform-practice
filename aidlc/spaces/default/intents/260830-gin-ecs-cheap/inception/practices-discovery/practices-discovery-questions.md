# Practices Discovery — Questions

このプロジェクトの進め方を確定します。単独・学習・使い捨て運用・低コスト前提なので、各項目は軽量な既定を提案しています。確認・修正をお願いします。

## Q1. 開発の進め方（ブランチ・マージ）

- A. トランクベース（短命ブランチ → `main` に squash マージ）。単独なので直接 `main` でも可
- B. 別の方針にしたい（内容を記述）
- X. Other (please specify)

[Answer]: A

## Q2. 最初に薄いエンドツーエンドのスライスを作りますか？（walking skeleton = 最小の `/healthz` だけのGinを GitHub Actions→ECR→ECS に一度通し、Terraformで最小ECS環境を立てて応答が返るところまでを最初に通す、という進め方）

- A. はい、まず walking skeleton でパイプラインとインフラの接続を証明してから実ロジックを載せる
- B. いいえ、いきなり作り込む
- X. Other (please specify)

[Answer]: A

## Q3. テストの方針

- A. test-after（実装後にそのレイヤのテスト）。Goは `go test` で happy-path 中心、Terraformは `validate`/`plan`。デプロイ後に `/healthz` スモーク。厳格なカバレッジ下限は課さない
- B. もっと厳格にしたい（TDD/カバレッジ下限など、内容を記述）
- X. Other (please specify)

[Answer]: A

## Q4. CI での lint の扱い（`golangci-lint` / `tflint` / `gitleaks` など）

支援レビューで「最低限のリンタは必須化する価値がある」との指摘がありました。

- A. 必須化する（`gofmt`/`go vet`/`golangci-lint`、`terraform fmt`/`validate`、`gitleaks` を CI 必須、失敗でブロック）
- B. 任意（警告のみ、ブロックしない）
- C. まだ決めない（後続で決める）
- X. Other (please specify)

[Answer]: A

## Q5. GitHub Actions から AWS への認証方式

- A. OIDC + IAM ロール引き受け（長期アクセスキーを GitHub Secrets に置かない）。信頼ポリシーを当該リポジトリ/ブランチに絞る。※セキュリティ・コスト両面で推奨
- B. 別の方式にしたい（内容を記述）
- X. Other (please specify)

[Answer]: A

## Q6. Terraform state の置き場所

- A. ローカル state（単独・使い捨て・最安優先。stateはコミットしない）
- B. S3 バックエンド（+必要ならDynamoDBロック）
- C. まだ決めない（インフラ設計フェーズで決める）
- X. Other (please specify)

[Answer]: A

## Q7. 環境の create → smoke → destroy を CI で自動化しますか？

- A. 手動運用（使うとき `terraform apply`、確認後 `terraform destroy`）。学習・使い捨てなので手動で十分
- B. CI で自動化（失敗時も必ず destroy してコスト残置を防ぐ）
- C. まだ決めない
- X. Other (please specify)

[Answer]: A

## Consolidated Summary Confirmation

以下の practices を確定し、team.md / project.md に反映します。よろしいですか？

- **進め方 (Q1):** トランクベース、短命ブランチ→`main` squash。単独は直接 main も可。
- **Walking Skeleton (Q2):** 最小 `/healthz` を GitHub Actions→ECR→ECS に通し、Terraform で最小 ECS 環境を立てて応答確認するところを最初に通す。
- **テスト (Q3):** test-after。Go は `go test` happy-path 中心（`httptest`）、Terraform は `validate`/`plan`、デプロイ後 `/healthz` スモーク（200 / `curl --fail`）、厳格カバレッジ下限なし。
- **CI lint (Q4):** `gofmt`/`go vet`/`golangci-lint`、`terraform fmt`/`validate`/`tflint`、`gitleaks` をブロッキングゲートとして必須化。
- **AWS 認証 (Q5):** GitHub Actions は OIDC + IAM ロール引き受け（長期キー禁止、信頼ポリシーを repo/branch 限定、最小権限）。
- **Terraform state (Q6):** ローカル state（使い捨て・最安）。state はコミットしない。
- **運用 (Q7):** create→smoke→destroy は手動運用（当面 CI 自動化なし）。
- **その他:** ECR scan-on-push (Basic)、コミット SHA タグ、distroless/scratch、`gin.ReleaseMode`、秘密は SSM、Actions は SHA ピン留め。

- Looks correct
- Request changes

[Answer]: Looks correct
