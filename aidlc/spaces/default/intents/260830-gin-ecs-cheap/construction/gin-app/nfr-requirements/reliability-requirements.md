# Reliability Requirements — gin-app

| ID | 要件 | 内容 |
|----|------|------|
| NFR2.1 | 可用性 | SLA/SLO なし。使い捨て運用（apply→確認→destroy）。常時稼働は前提としない [requirements NFR2] |
| NFR2.2 | ヘルスチェック | `/healthz` が 200 を返し、ECS のコンテナヘルスチェックに用いる。ALB が無く distroless（curl/シェル無し）のため、タスク定義の `healthCheck` から `CMD` 形式でアプリ自身の `-healthcheck` モード（自分の `/healthz` を叩き終了コードで返す）を呼ぶ。UNHEALTHY 時は ECS がタスクを置き換える [FR1.1] |
| NFR2.3 | フォールトトレランス | 単一タスク。自動フェイルオーバーなし。異常時は destroy して作り直す |
| NFR2.4 | データ耐久性 | 学習用ダミーデータのみ。バックアップ不要。RDS は破棄時にスナップショットを残さない [FR4.2] |
| NFR2.5 | グレースフルシャットダウン | 可能なら SIGTERM を受けて Gin をグレースフルに停止（学習として推奨、必須ではない） |

根拠: 使い捨て・低リスク・単独 [requirements NFR2]。

<!-- Confirmed by human (summary-confirmation: Looks correct). -->
