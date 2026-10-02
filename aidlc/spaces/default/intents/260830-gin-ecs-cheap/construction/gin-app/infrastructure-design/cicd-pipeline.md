# CI/CD Pipeline Design — gin-app

GitHub → GitHub Actions → ECR → ECS。`main` へのマージ（または手動 dispatch）で起動。OIDC で AWS 認証（長期キーなし）。

## パイプライン ステージ → ゲート

| ステージ | 内容 | ゲート（失敗でブロック） |
|----------|------|--------------------------|
| 1. Lint/Format | `gofmt -l`、`go vet`、`golangci-lint`（errcheck/staticcheck/govet） | ✅ [project.md Mandated] |
| 2. Secret scan | `gitleaks` | ✅ |
| 3. Test | `go test ./...`（-cover 可視化のみ） | ✅（テスト失敗でブロック） |
| 4. Terraform 検証 | `terraform fmt -check`、`terraform validate`、`tflint` | ✅ |
| 5. Build image | Docker マルチステージ（distroless/scratch）、SHAタグ | ✅ |
| 6. AWS 認証 | `aws-actions/configure-aws-credentials`（OIDC、`id-token: write`、`role-to-assume`） | 長期キー不使用 [NFR3.1] |
| 7. ECR push | SHAタグで push（`latest` 非依存） | [FR2.2] |
| 8. ECS deploy | タスク定義を新イメージで更新しサービスをデプロイ | |
| 9. Smoke | `/healthz` に `curl --fail`、数回リトライで 200 確認 | ✅ [FR6.1][FR6.2] |

## デプロイ戦略

- **rolling**（ECS サービスの標準更新）。単一タスクのため実質置き換え。blue-green/canary は最安・使い捨て用途では過剰。
- **ロールバック**: 直前のコミット SHA タグのイメージへ ECS サービスを手動で戻す。自動ロールバックなし [team-practices]。

## 環境プロモーション

- 単一エフェメラル環境のみ。dev→stg→prod のプロモーションなし。

## CI/CD でのシークレット管理

- AWS 認証は OIDC 引き受けロール（GitHub Secrets に長期キーを置かない）[project.md Forbidden]。
- サードパーティ Action はコミット SHA でピン留め [FR5.3]。
- DB 認証情報等の秘密は SSM Parameter Store。ワークフローに平文で書かない。

## 補足（create→smoke→destroy の自動化範囲）

- 当面、環境の create/destroy は手動運用（`terraform apply`/`destroy`）。CI は build/push/deploy/smoke に集中し、コスト残置を避けるため使い終わりの destroy は人間が実行する [Q7=A]。

<!-- confirmed -->

