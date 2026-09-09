# Requirements Analysis — Questions

要件を確定するための残りの確認事項です。意図・practices で既に決まっている点（学習目的・単独・使い捨て・月1000円以内・OIDCパイプライン）は前提として扱います。主に、実際に作る Gin アプリと ECS 構成の細部を詰めます。

## Q1. Gin サーバーが提供するエンドポイントは？

- A. `/healthz`（ヘルスチェック、200を返す）のみ。学習・動作確認に必要な最小限
- B. `/healthz` に加えて、簡単なサンプルエンドポイント（例: `/` や `/hello` が固定JSONを返す）も欲しい
- C. もっと具体的なAPIがある（内容を記述）
- D. Not yet defined
- X. Other (please specify)

[Answer]: A

## Q2. ECS の起動タイプ（コストに直結）

- A. Fargate（サーバー管理不要。最小 vCPU/メモリ = 0.25vCPU/0.5GB。使うときだけ起動で最安を狙う）
- B. Fargate Spot（さらに安いが中断あり。学習・使い捨てなら許容）
- C. EC2 起動タイプ（t系スポット等。運用は増えるが理論上さらに安い場合も）
- D. おまかせ（インフラ設計で最安を選定）
- X. Other (please specify)

[Answer]: A

## Q3. 外部からのアクセス方法（コスト・構成に直結）

- A. ALB なし。タスクにパブリックIPを付与し、直接 `http://<public-ip>:<port>` でアクセス（最安。ALB課金を避ける）
- B. ALB あり（HTTPS終端・安定URL。ただし ALB は課金される）
- C. おまかせ（インフラ設計で最安を選定）
- X. Other (please specify)

[Answer]: A

## Q4. ネットワーク構成（NAT Gateway はコストが高い）

- A. パブリックサブネットにタスクを置き、NAT Gateway は使わない（最安。ECRイメージ取得はパブリック経路 or VPCエンドポイント）
- B. プライベートサブネット + NAT Gateway（本番的だが NAT が高コスト）
- C. おまかせ（インフラ設計で最安を選定）
- X. Other (please specify)

[Answer]: A

## Q5. リージョン

- A. `ap-northeast-1`（東京）
- B. `us-east-1`（バージニア北部、最安リージョンの一つ）
- C. おまかせ／どこでもよい
- X. Other (please specify)

[Answer]: A

## Q6. 動作確認（スモーク）の合否基準

- A. `/healthz` に対して HTTP 200 が返れば成功（`curl --fail`、数回リトライ）
- B. 別の基準がある（内容を記述）
- X. Other (please specify)

[Answer]: A

## Q7. データストアの用途と方針（追加要件: MySQL を使いたい）

- A. RDS for MySQL を第一候補にする。最安構成（`db.t4g.micro`、Single-AZ、最小ストレージ、使うときだけ apply、終わったら destroy でスナップショットも残さない）。1000円が厳しければ次善策（DynamoDB 等）を検討
- B. 最初から DynamoDB で行く（オンデマンド課金、KVS）
- C. RDS を第一候補にしつつ、1000円超が見込まれるなら DynamoDB へ切り替える方針
- D. おまかせ（インフラ設計で最安を選定）
- X. Other (please specify)

[Answer]: A

## Q8. Gin アプリからの DB 利用範囲

- A. 学習・動作確認レベル。1テーブルへの簡単な CRUD、または DB 接続して1行読める/書けることを確認できれば十分。スキーマ初期化は GORM の AutoMigrate で行う
- B. もう少し具体的なデータモデル・機能がある（内容を記述）
- C. 未定（設計フェーズで詰める）
- X. Other (please specify)

[Answer]: A

## Consolidated Summary Confirmation

以下の理解で requirements.md を生成します。よろしいですか？

- **エンドポイント (Q1):** `/healthz`（200を返す）を最小限として持つ。
- **ECS 起動タイプ (Q2):** Fargate、最小サイズ（0.25 vCPU / 0.5GB 目安）、使うときだけ起動。
- **外部アクセス (Q3):** ALB なし。タスクにパブリック IP を付与して直接アクセス（ALB 課金を回避）。
- **ネットワーク (Q4):** パブリックサブネット配置、NAT Gateway なし（最安）。
- **リージョン (Q5):** `ap-northeast-1`（東京）。
- **スモーク基準 (Q6):** `/healthz` に HTTP 200（`curl --fail`、数回リトライ）で成功。
- **データストア (Q7):** RDS for MySQL を第一候補（`db.t4g.micro`、Single-AZ、最小ストレージ、使うとき apply・終わったら destroy でスナップショットも残さない）。月1000円が厳しければ DynamoDB 等の次善策を検討。
- **DB 利用範囲 (Q8):** 学習レベルの簡単な CRUD／接続確認。スキーマ初期化は GORM の AutoMigrate。
- **横断前提:** 使い捨て運用（apply→確認→destroy）、月額コスト1000円以内が目標、ビルド・デプロイは GitHub→GitHub Actions→ECR→ECS（OIDC 認証）。

- Looks correct
- Request changes

[Answer]: Looks correct
