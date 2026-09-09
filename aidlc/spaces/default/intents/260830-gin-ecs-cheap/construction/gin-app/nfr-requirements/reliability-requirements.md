# Reliability Requirements — gin-app

| ID | 要件 | 内容 |
|----|------|------|
| NFR2.1 | 可用性 | SLA/SLO なし。使い捨て運用（apply→確認→destroy）。常時稼働は前提としない [requirements NFR2] |
| NFR2.2 | ヘルスチェック | `/healthz` が 200 を返し、ECS のヘルスチェックに用いる [FR1.1] |
| NFR2.3 | フォールトトレランス | 単一タスク。自動フェイルオーバーなし。異常時は destroy して作り直す |
| NFR2.4 | データ耐久性 | 学習用ダミーデータのみ。バックアップ不要。RDS は破棄時にスナップショットを残さない [FR4.2] |
| NFR2.5 | グレースフルシャットダウン | 可能なら SIGTERM を受けて Gin をグレースフルに停止（学習として推奨、必須ではない） |

根拠: 使い捨て・低リスク・単独 [requirements NFR2]。

<!-- Confirmed by human (summary-confirmation: Looks correct). -->
