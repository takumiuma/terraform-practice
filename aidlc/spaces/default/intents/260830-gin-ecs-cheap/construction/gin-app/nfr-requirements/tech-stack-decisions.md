# Tech Stack Decisions — gin-app

| 項目 | 選択 | 根拠 |
|------|------|------|
| 言語 | Go | intent（Gin=Go の Web フレームワーク） |
| Web フレームワーク | Gin | intent で明示 |
| ORM / DB ドライバ | GORM + MySQL ドライバ（`gorm.io/driver/mysql`） | ユーザー指定（AutoMigrate でスキーマ初期化）[FR1.3] |
| DB | MySQL（RDS、Bolt2で追加） | ユーザー指定 [FR4.1] |
| コンテナベースイメージ | distroless または scratch（マルチステージビルド、静的バイナリ） | 最小サイズ・攻撃面縮小・転送/ストレージコスト削減 [team-practices] |
| 設定の受け渡し | 環境変数（実体は SSM Parameter Store） | 秘密の非ハードコード [NFR3.1] |
| Go バージョン | 1.22 以降（安定版） | 現行の安定版。`go.mod` でピン |
| テスト | 標準 `go test` + `net/http/httptest` | team-practices Testing Posture |

## 補足

- Bolt1（walking skeleton）では `/healthz` のみ。GORM/MySQL 依存は Bolt2 で追加する（skeleton を軽く保つため、Bolt1 の Docker イメージに DB ドライバは含めても未使用で可）。

<!-- Confirmed by human (summary-confirmation: Looks correct). -->
