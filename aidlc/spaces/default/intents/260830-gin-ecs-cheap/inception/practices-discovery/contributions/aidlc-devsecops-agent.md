**Collaborator:** aidlc-devsecops-agent

## Contribution

DevSecOps 観点で、LEAD ドラフトの5セクションと discovered-rules をレビューした。単独・学習/実験・低コスト（月額 ¥1000 未満）という制約を尊重し、重い商用ツール（SonarQube、Snyk 有償、DAST スイート、Shield Advanced 等）は不要と判断する。一方で、パイプラインが AWS 本番アカウントに触れ、Terraform state が認証情報を含みうる以上、コスト無関係で守るべき「本物のセキュリティ必須事項」がいくつかある。以下は Way of Working / Deployment / Code Style / discovered-rules への統合を意図した具体的な findings。

### 1. GitHub Actions → AWS 認証は OIDC/IAM ロール一択（長期キー禁止）
ディスパッチブリーフの通り、GitHub Actions は OIDC で AWS の IAM ロールを引き受ける構成が正しい。これはコストゼロで、最大級のセキュリティ改善になる。以下を明文化することを推奨する。
- `aws-actions/configure-aws-credentials` を OIDC モード（`role-to-assume` + `id-token: write` パーミッション）で使い、`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` を GitHub Secrets に保存しない。
- 引き受ける IAM ロールの信頼ポリシーの `sub` 条件を、当該リポジトリかつ特定ブランチ（例: `repo:<owner>/<repo>:ref:refs/heads/main`）に厳格に絞る。ワイルドカード `repo:<owner>/*` は避ける。学習用でも、緩い信頼ポリシーは第三者リポジトリからのロール横取りにつながる典型的な設定ミス。
- デプロイロールの権限は ECR push + ECS デプロイ + 必要な Terraform 操作に絞る最小権限とする。学習初期は広めでも、`AdministratorAccess` を GitHub Actions ロールに与えるのは避け、後で絞る前提とする。

これらは discovered-rules の Forbidden に「NEVER 長期 AWS アクセスキーを GitHub Secrets に保存する（OIDC/IAM ロールで認証する）」、Mandated に「ALWAYS GitHub Actions の AWS 認証は OIDC + 引き受けロールで行い、信頼ポリシーをリポジトリ/ブランチで絞る」を追加する価値がある。

### 2. Terraform state のシークレット取り扱い
現状の `.gitignore` は `*.tfstate` / `*.tfstate.backup` / `.terraform` を正しく除外しており、この点は良好。ただし evidence の未解決事項（ローカル vs S3+DynamoDB）はセキュリティ上も重要なので補足する。
- state はプレーンテキストで機密（ARN、時にパスワードやトークン）を含みうる。リポジトリへ絶対にコミットしない現行の除外は Forbidden ルールとして維持すべき（LEAD の「NEVER state をコミット」は妥当、支持）。
- リモート state を使う場合は S3 バケットで SSE（デフォルトの SSE-S3 で十分、KMS は任意）とパブリックアクセスブロックを有効化する。単独開発ならロック（DynamoDB）は必須ではないが、S3 バージョニングは誤操作復旧に安価で有効。
- ローカル state 運用でも、`terraform.tfvars` や `*.auto.tfvars` に秘密を書かない。秘密は SSM Parameter Store（標準パラメータは無料枠）で扱う方針を推奨。

### 3. シークレットスキャン（コスト無料で導入価値大）
学習プロジェクトでも、AWS 認証情報やトークンの誤コミットは実害が出る唯一クラスのミス。無料で以下を推奨。
- GitHub の Secret Scanning + Push Protection（パブリックリポジトリは無料、プライベートも設定で有効化可能）を有効にする。
- CI に軽量な `gitleaks` を1ジョブ追加し、検知時はマージをブロック。pre-commit フックは任意（単独なら CI 側だけでも実用上十分）。
- 誤コミット時の対応（即時 revoke → ローテーション → 履歴クリーン）を運用メモに残す。

### 4. ECR イメージスキャン（ECR ネイティブ、追加コストほぼゼロ）
- ECR リポジトリで「scan on push」（Basic scanning）を有効化する。Basic は無料。Enhanced（Inspector）は課金対象なので、コスト目標を考えると学習フェーズでは Basic で十分。
- ベースイメージは distroless か Alpine など最小構成にし、攻撃面とイメージサイズ（= 転送/ストレージコスト）の両方を下げる。Go はスタティックバイナリを distroless/scratch に載せる構成が定番で、コストとセキュリティが両立する。
- Critical 検出時はデプロイを止める、を努力目標に。学習フェーズでは警告扱いでも可だが、方針として明記する。

### 5. 依存・IaC スキャン（軽量に）
- Go: CI に `govulncheck`（Go 公式・無料）を1ステップ追加。`golangci-lint` は既にドラフトにあり good。GitHub の Dependabot（無料）で `go.mod` と GitHub Actions の更新 PR を受ける。
- Terraform: `terraform validate` に加え、`tflint` と、可能なら `Checkov`（無料）または `tfsec` を CI に軽く通す。公開 S3、暗号化なし、過度に緩い IAM/セキュリティグループを検出できる。学習用途では警告レベルからで良い。
- GitHub Actions のサードパーティアクションはメジャータグではなくコミット SHA でピン留めする（サプライチェーン対策、コスト無関係）。

### 6. アプリ層の最小限のセキュア既定（Gin）
学習用でも secure-by-default にしておくと後で楽。
- ECS の前段（ALB か、コスト最小なら直接）で HTTPS を終端し、平文 HTTP を避ける。ACM 証明書は無料。
- Gin のエラーレスポンスでスタックトレース等の内部情報を返さない（本番相当モード: `gin.SetMode(gin.ReleaseMode)`）。
- 全入力のバリデーションと、ログに秘密（トークン/認証情報）を出さない方針を Code Style に一言添える。

### 7. DAST について
DAST スイート（OWASP ZAP 等）はこの規模・目的では過剰。エフェメラル環境に対する既存の `/healthz` スモークテストで健全性確認するだけで、この段階では十分と判断する（将来 API が育ったら再検討）。

### Code Style への追記提案
LEAD の Code Style は妥当。ここに「秘密はコード/tfvars にハードコードせず SSM Parameter Store 等で扱う」「サードパーティ GitHub Action は SHA ピン留め」の2点を add すると、セキュリティ実務と一致する。

## Positions

AGREE: トランクベース + squash + エフェメラル運用の Way of Working / Deployment は、単独・低コスト・学習目的に合致しており妥当。
AGREE: discovered-rules の「NEVER state をコミット」「NEVER latest タグに依存」「ALWAYS コミット SHA タグ」はセキュリティ/再現性の観点でも正しい必須事項。
AGREE: `.gitignore` の `*.tfstate` 系除外は現状で適切。
OBJECT: GitHub Actions → AWS の認証方式が明文化されていない。長期キー禁止・OIDC/IAM ロール必須をルール化すべき（コストゼロで効く最大の必須事項）。
OBJECT: シークレットスキャン（GitHub Push Protection + `gitleaks`）が practices に含まれていない。誤コミットは学習用途でも実害があり、無料で導入可能なため必須級。
OBJECT: ECR の scan-on-push（Basic・無料）が明記されていない。CI/デプロイの最低限のイメージ健全性チェックとして加えるべき。
