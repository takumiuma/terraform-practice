# NFR Requirements — gin-app

要件（requirements.md）と practices で NFR はほぼ確定しているため、追加質問はなし。要件から直接 NFR を導出した。

## Consolidated Summary Confirmation

gin-app の NFR を以下で確定します（学習・使い捨て・最安の方針に沿った最小限）:

- **性能:** `/healthz` は通常 <500ms 目安、負荷試験対象外、Fargate 最小サイズで動作
- **セキュリティ:** 秘密は SSM 経由（ハードコードなし）、ReleaseMode で内部情報を返さない、入力検証、ログに秘密を出さない、アプリ層の認証はスコープ外
- **スケーラビリティ:** 単一タスク（desired=1）、オートスケールなし
- **信頼性:** SLAなし、`/healthz` ヘルスチェック、使い捨て、RDSはスナップショット残さない
- **可観測性:** 標準出力ログ→CloudWatch Logs、専用監視/トレースなし
- **技術選定:** Go + Gin + GORM(MySQL)、distroless/scratch、設定は環境変数(SSM)

- Looks correct
- Request changes

[Answer]: Looks correct
