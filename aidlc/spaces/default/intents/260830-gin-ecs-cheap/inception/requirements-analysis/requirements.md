# Requirements — Gin on ECS (Cheapest, Terraform, with MySQL)

## Intent Analysis

開発者本人が AWS・Terraform・ECS を学ぶために、Gin (Go) の HTTP サーバーを Amazon ECS 上で最小コスト（月額1,000円以内が目標）で動かす。MySQL（RDS）を使ったDBアクセスも学習対象に含める。常時稼働の本番運用ではなく、必要なときだけ `terraform apply` で立ち上げ、動作確認したら `terraform destroy` で破棄する使い捨て運用を、Terraform で再現可能に構築することが狙い。[intent-statement]

## Functional Requirements

### FR1: Gin HTTP サーバー
- **FR1.1** Gin サーバーは `/healthz` エンドポイントを提供し、正常時に HTTP 200 を返す。[Q1][Q6]
- **FR1.2** Gin サーバーは MySQL に接続し、学習レベルの簡単な CRUD（または1行の read/write 確認）を行うエンドポイントを提供する。[Q7][Q8]
- **FR1.3** アプリ起動時に GORM の AutoMigrate でスキーマ（1テーブル程度）を初期化する。[Q8]
- **FR1.4** Gin は本番相当モード（`gin.SetMode(gin.ReleaseMode)`）で動作し、エラーレスポンスに内部情報（スタックトレース等）を含めない。[team-practices Code Style]

### FR2: コンテナ化とイメージ配信
- **FR2.1** Gin アプリを Docker イメージとしてビルドし、最小構成のベースイメージ（distroless または scratch）に Go スタティックバイナリを載せる。[team-practices Deployment]
- **FR2.2** イメージは ECR リポジトリに push し、タグはコミット SHA を用いる（`latest` に依存しない）。[team-practices]

### FR3: ECS 実行環境（Terraform）
- **FR3.1** Terraform で ECS 上に Gin サーバーを起動する。起動タイプは Fargate、最小サイズ（0.25 vCPU / 0.5 GB を目安）とする。[Q2]
- **FR3.2** タスクはパブリックサブネットに配置し、パブリック IP を付与して外部から直接アクセスできる。ALB は使わない。[Q3][Q4]
- **FR3.3** NAT Gateway は使わない。ECR からのイメージ取得はパブリック経路または VPC エンドポイントで賄う。[Q4]
- **FR3.4** リージョンは `ap-northeast-1`（東京）とする。[Q5]

### FR4: データストア（RDS for MySQL、使い捨て）
- **FR4.1** MySQL は Amazon RDS for MySQL を第一候補とし、最安構成（`db.t4g.micro`、Single-AZ、最小ストレージ）で Terraform 管理する。[Q7]
- **FR4.2** RDS は使い捨て運用とする。`terraform apply` で作成、`terraform destroy` で破棄し、破棄時に最終スナップショットを残さない（`skip_final_snapshot = true` 相当）。[Q7][intent-statement]
- **FR4.3** DB 接続情報（エンドポイント・認証情報）はコード/tfvars にハードコードせず、SSM Parameter Store 等で扱い、ECS タスクへ安全に渡す。[team-practices][project.md Forbidden]
- **FR4.4** 【フォールバック条件】RDS 構成で月額コストが1,000円を超える見込みが強い場合、DynamoDB（オンデマンド課金）等の次善策をインフラ設計フェーズで検討・提案する。[Q7]

### FR5: ビルド・デプロイパイプライン
- **FR5.1** GitHub にソースを置き、`main` へのマージを契機に GitHub Actions が動く。パイプラインは Go ビルド/テスト → Docker イメージビルド → ECR push（SHA タグ）→ ECS デプロイの順で進む。[intent-statement][team-practices Deployment]
- **FR5.2** GitHub Actions から AWS への認証は OIDC + IAM ロール引き受けで行い、長期アクセスキーを GitHub Secrets に置かない。信頼ポリシーは当該リポジトリ/ブランチに絞り、デプロイロールは最小権限とする。[project.md Mandated][Q5 認証方針]
- **FR5.3** サードパーティの GitHub Actions はコミット SHA でピン留めする。[team-practices]

### FR6: 動作確認（スモーク）
- **FR6.1** デプロイ後、`/healthz` に対して HTTP 200 が返ることをスモークテストで確認する。判定は `curl --fail` の終了コードで行い、数秒間隔で数回リトライする。[Q6][team-practices Testing Posture]
- **FR6.2** デプロイはスモークが通って初めて完了とみなす。[team-practices]

## Non-Functional Requirements

- **NFR1 (コスト):** 一連の検証（apply → 動作確認 → destroy）にかかる月額コストは1,000円以内を目標とする。ALB・NAT Gateway など高コストな常設リソースを既定にしない。RDS は使うときだけ起動し、破棄時にスナップショット等の残存課金を残さない。[intent-statement][Q7]
- **NFR2 (使い捨て・再現性):** `terraform apply` で全リソース（VPC/サブネット/ECS/RDS/ECR/IAM 等）を作成でき、`terraform destroy` で残存課金なく破棄できる。Terraform state はローカルに置き、リポジトリにコミットしない。[intent-statement][team-practices]
- **NFR3 (セキュリティ):** AWS 認証は OIDC + IAM ロール（長期キー禁止）。秘密（DB 認証情報等）は state/tfvars/ログに出さず SSM 等で扱う。ECR は scan-on-push（Basic）を有効化する。[project.md Mandated/Forbidden]
- **NFR4 (可観測性):** 学習用途のため最小限。ECS タスク/コンテナのログが確認できれば十分（CloudWatch Logs 等、無料枠を意識）。[intent-statement]
- **NFR5 (テスト):** test-after。Go ハンドラは `httptest` で happy-path 中心のユニットテスト、Terraform は `validate`/`plan`。厳格なカバレッジ下限は課さない。[team-practices Testing Posture]

## Constraints

- **C1:** インフラは Terraform で実装する（IaC）。[intent-statement]
- **C2:** ランタイムは AWS ECS。アプリは Gin (Go)。DB は MySQL（RDS 第一候補）。[intent-statement][Q7]
- **C3:** CI で `gofmt`/`go vet`/`golangci-lint`、`terraform fmt`/`validate`/`tflint`、`gitleaks` をブロッキングゲートとして実行する。[project.md Mandated]
- **C4:** Terraform は `main.tf`/`variables.tf`/`outputs.tf`/`versions.tf` に分割し、`versions.tf` でバージョンピン留めする。[team-practices Code Style]

## Assumptions

- **A1:** 利用は短時間の学習・動作確認であり、RDS/ECS を常時起動しない前提であれば月1,000円以内は達成可能と見込む（実測はインフラ設計・検証フェーズで確認）。[assumption][Q7]
- **A2:** GitHub リポジトリと AWS アカウントは利用者が用意する（本ワークフローの対象外）。[assumption]
- **A3:** ECR イメージや state など、破棄後も残ると課金され得るものは destroy 時に確実に消える構成にする（詳細はインフラ設計で確定）。[assumption][intent-statement]

## Out of Scope

- 常時稼働の本番運用、複数環境（staging/prod）への展開。[intent-statement]
- 外部エンドユーザー向けの提供、認証・認可などのアプリ機能（学習範囲を超えるもの）。[intent-statement]
- ALB/HTTPS 終端・独自ドメイン（最安構成のため当面持たない。将来検討）。[Q3]
- 自動ロールバック、CI での create→smoke→destroy 完全自動化（当面は手動運用）。[team-practices]

## Open Questions（後続フェーズで確定）

- **OQ1:** RDS 最安構成の実測月額が1,000円以内に収まるか。超える場合の DynamoDB への切り替え判断。→ NFR 要件・インフラ設計フェーズ。[Q7]
- **OQ2:** ECR イメージ取得をパブリック経路にするか VPC エンドポイントにするか（NAT なし構成での経路確保）。→ インフラ設計フェーズ。[Q4]
- **OQ3:** OIDC で引き受ける IAM ロールの具体的な信頼ポリシーと権限境界。→ インフラ設計フェーズ。[FR5.2]

## Review

**Verdict:** READY
**Reviewer:** aidlc-product-lead-agent
**Date:** 2026-08-31T12:00:55Z
**Iteration:** 1

### Findings

| ID | Severity | Location | Finding | Required action | Status |
|---|---|---|---|---|---|
| R-01 | Minor | aidlc/spaces/default/intents/260830-gin-ecs-cheap/inception/requirements-analysis/requirements.md > FR4.4 / NFR1 / A1 / OQ1 | ¥1,000/月の目標に測定基準（計測窓＝暦月かapply〜destroyの実稼働時間ベースか、課金対象リソースの範囲）がない。RDS `db.t4g.micro` はストレージ＋起動時間だけでも目標を圧迫しうるが、要件はこのリスクを FR4.4 のフォールバック条件・OQ1・A1 の「実測は後続フェーズで確認」で正直に明示しており、目標（goal）として扱われている。学習プロジェクトとしては right-sized。 | 後続のインフラ設計/検証フェーズで測定窓と課金対象範囲を確定し、FR4.4 のフォールバック発動しきい値（例: 実測◯円超）を具体化する。intent-statement R-02 から引き継ぐ論点で、本ゲートは阻害しない。 | New |
| R-02 | Minor | aidlc/spaces/default/intents/260830-gin-ecs-cheap/inception/requirements-analysis/requirements.md > FR1.2 | 「簡単な CRUD（または1行の read/write 確認）」がどのエンドポイント/操作を指すか一意でなく、QAがこの記述だけからテストケースを一意に導出できない。Q8=A の学習レベル方針には合致し、GORM AutoMigrate＋接続確認（FR1.3）で最小要件は満たせるため学習用途では許容範囲。 | 後続の設計フェーズで、確認対象エンドポイントと期待挙動（例: POST→GET で同一レコードが読める）を1つ具体化する。学習スコープでは阻害しない。 | New |
| R-03 | Minor | aidlc/spaces/default/intents/260830-gin-ecs-cheap/inception/requirements-analysis/requirements.md > FR4.4 | フォールバック条件が「1,000円を超える見込みが強い場合」と定性的で、そのままではテスト可能な合否基準にならない。ただし判断自体を OQ1 でインフラ設計フェーズへ明示的に委譲しており、要件段階では open question として適切に記録されている。 | R-01 の測定基準確定とあわせて発動条件を数値化する。 | New |

### Summary

要件は Q1〜Q8 の確認済み回答・intent-statement・team-practices・project.md の Mandated/Forbidden に漏れなくトレースでき、孤立要件や矛盾はなく、単独学習プロジェクトとして適切なサイズに収まっている。¥1,000＋RDS のコストリスクはフォールバック（FR4.4）・OQ1・A1 で正直にフラグ済みで、開発者は要件フェーズを離れられる状態。残る3件はいずれも後続フェーズで確定すべき測定基準・具体化の Minor で、承認を阻害しない。
