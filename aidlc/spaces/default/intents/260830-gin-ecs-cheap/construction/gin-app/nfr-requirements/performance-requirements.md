# Performance Requirements — gin-app

学習・使い捨て用途のため、性能要件は最小限。

| ID | 要件 | 目標/基準 |
|----|------|-----------|
| NFR1.1 | `/healthz` の応答時間 | ローカル/最小Fargateで通常 < 500ms（厳密なSLAは課さない） |
| NFR1.2 | スループット | 単独の動作確認用途。同時アクセスは想定せず、負荷試験の対象外 |
| NFR1.3 | リソース | Fargate 最小サイズ（0.25 vCPU / 0.5GB）で動作すること |

根拠: intent の「動作確認レベル」「最安構成」[requirements NFR1]。

<!-- Confirmed by human (summary-confirmation: Looks correct). -->
