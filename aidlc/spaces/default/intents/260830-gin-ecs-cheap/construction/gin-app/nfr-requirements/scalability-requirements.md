# Scalability Requirements — gin-app

| ID | 要件 | 内容 |
|----|------|------|
| NFR1.4 | スケーリング | オートスケーリングなし。ECS サービスは desired count = 1 の単一タスク。学習・使い捨て用途で負荷増は想定しない |
| NFR1.5 | 同時実行 | 単独の動作確認。並行性の目標なし |

根拠: 最安構成・使い捨て・単独 [requirements NFR1]。常設・高コストリソースを既定にしない [project.md Mandated]。

<!-- Confirmed by human (summary-confirmation: Looks correct). -->
