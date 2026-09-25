# Observability Requirements — gin-app

| ID | 要件 | 内容 |
|----|------|------|
| NFR4.1 | ログ | 標準出力に構造化なしの簡易ログ（Gin の既定ロガーで可）。ECS から CloudWatch Logs に送る。秘密は出力しない [NFR3.4] |
| NFR4.2 | メトリクス/トレース | 専用の監視・分散トレースは導入しない（学習用途・最小限） [requirements NFR4] |
| NFR4.3 | アラート | なし（使い捨て・単独） |
| NFR4.4 | 動作確認 | `/healthz` へのスモークで健全性を確認 [FR6.1] |

根拠: 最小限の可観測性 [requirements NFR4]。無料枠を意識。

<!-- Confirmed by human (summary-confirmation: Looks correct). -->
