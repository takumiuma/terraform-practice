# Monitoring Design — gin-app（最小限）

学習・使い捨て用途のため監視は最小限。CloudWatch Logs のみを基本とし、専用の監視スタックは持たない。

## Metrics & KPIs

| Metric | Source | Threshold | Why it matters |
|--------|--------|-----------|----------------|
| ECS タスク RUNNING 数 | ECS/CloudWatch | 期待 1 | タスクが起動しているか |
| `/healthz` 応答 | 手動 curl / スモーク | HTTP 200 | サービス健全性 [FR6.1] |

## Alerts

| Alert | Condition | Severity | Routes to |
|-------|-----------|----------|-----------|
| （なし） | — | — | 使い捨て・単独のためアラートは設定しない |

## SLIs / SLOs

| SLI | SLO target | Measurement window |
|-----|-----------|---------------------|
| （なし） | SLA/SLOは課さない | — [NFR2.1] |

## Logs & Tracing

- ログ: ECS タスクの標準出力を CloudWatch Logs に転送。ロググループの retention は 1〜3 日（低コスト）。秘密は出力しない [NFR3.4]。
- トレース: 分散トレースは導入しない [NFR4.2]。
- ダッシュボード: なし。必要時は CloudWatch のログを直接確認。

<!-- confirmed -->

