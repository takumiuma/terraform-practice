# gin-ecs-cheap

Gin (Go) の HTTP サーバーを **AWS ECS Fargate 上で最安・使い捨て**で動かすための学習用プロジェクト。
インフラは Terraform、ビルド・デプロイは GitHub Actions（GitHub → Actions → ECR → ECS、OIDC 認証）。

- **リージョン:** `ap-northeast-1`（東京）
- **運用モデル:** 使うときだけ `terraform apply`、終わったら `terraform destroy`（常時稼働しない）
- **コスト目標:** 月 1,000 円以内。ALB / NAT Gateway を持たないことが最安の要。

## リポジトリ構成

```
app/                     Gin アプリ（Go）
  cmd/server/main.go     エントリポイント（ReleaseMode / graceful shutdown / DB接続）
  internal/handler/      ルーティング・ハンドラ・DB(GORM)・テスト
  Dockerfile             distroless マルチステージ（静的バイナリ・非root・amd64固定）
infra/                   Terraform 一式（VPC/ECS/ECR/RDS/IAM-OIDC/SSM/Logs）
.github/workflows/       CI/CD（lint/test/tf検証 → build → ECR push → ECS deploy → smoke）
legacy-ec2-practice/     過去の EC2/ASG/ALB 練習用コード（本命とは無関係・退避）
```

## アーキテクチャ（最安構成）

- **ECS Fargate** 最小サイズ（0.25 vCPU / 0.5 GB）、desired count = 1、オートスケールなし
- **ネットワーク:** VPC + パブリックサブネット(2AZ) + IGW。**NAT Gateway なし**。タスクにパブリック IP を直付け
- **公開:** **ALB なし**。`http://<タスクのパブリックIP>:8080` に直接アクセス
- **ECR:** scan-on-push(Basic) 有効、**イメージタグは IMMUTABLE**（同名タグの上書き不可）、コミット SHA タグ運用、`force_delete`（destroy で削除）
- **DB（任意・Bolt2）:** RDS for MySQL `db.t4g.micro` / Single-AZ / 最小ストレージ / `skip_final_snapshot` / 非公開
- **秘密:** SSM Parameter Store（SecureString）→ ECS タスクへ注入。コード/tfvars には置かず `TF_VAR_db_password` で渡す。
  ただし DB パスワードはローカル state に平文で残る（`sensitive` は表示を隠すだけ）。
  学習・使い捨て（ダミーデータのみ、state はコミットしない）前提のため許容している
- **state:** ローカル（`infra/` 内）。コミットしない（`.gitignore` 済み）

## エンドポイント

| メソッド | パス | 説明 |
|----------|------|------|
| GET | `/healthz` | ヘルスチェック。`{"status":"ok"}` を返す（DB非依存） |
| POST | `/items` | アイテム作成。ボディ `{"name":"..."}`。DB有効時のみ |
| GET | `/items` | アイテム一覧。DB有効時のみ |

`enable_db=false`（skeleton）では `/healthz` のみ。`/items` は 404 になる。

## 前提

- AWS アカウントと認証（`aws configure` 済み、または適切な権限のプロファイル）。
  作成先アカウントは `aws sts get-caller-identity` で事前確認できる
- Terraform >= 1.9、Go 1.22+、Docker（ローカルビルド時）、`jq`（CIで使用）
- GitHub リポジトリ（CI/CD を使う場合）

## 使い方: 段階的に立てる

`infra/variables.tf` のフラグで構成を切り替える。

- `enable_db`（既定 `false`）: `true` で RDS(MySQL) を作成
- `image_tag`（既定 `bootstrap`）: デプロイする ECR イメージのタグ（コミット SHA 等）
- `create_github_oidc`（既定 `false`）: `true` で GitHub Actions 用 OIDC プロバイダ + IAM ロールを作成

> **重要（初回の順序）:** タスク定義は `<ECR>:<image_tag>` を参照する。ECR にそのタグの
> イメージが無い状態でいきなり全部 apply すると、ECS が存在しないイメージを引こうとして
> `CannotPullImage` で起動失敗する。**先に ECR だけ作ってイメージを push** してから、
> そのタグで残りを apply すること（下記手順）。

### ステップ 1: ECR を作ってイメージを push

```bash
cd infra
terraform init

# ECR リポジトリだけ先に作る
terraform apply -target=aws_ecr_repository.app

# ECR にログイン
REPO=$(terraform output -raw ecr_repository_url)
REGISTRY=${REPO%/*}
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin "$REGISTRY"

# イメージをビルドして push（タグはコミット SHA。Dockerfile で amd64 固定済み）
cd ../app
SHA=$(git rev-parse --short HEAD)
docker build -t "$REPO:$SHA" .
docker push "$REPO:$SHA"
```

> **タグは IMMUTABLE:** 一度 push したタグには上書き push できない。コードを変えて
> 作り直すときは新しいタグにする（例: `SHA=$(git rev-parse --short HEAD)` を打ち直す、
> または `"$SHA-2"` のように付ける）。

### ステップ 2A: walking skeleton（`/healthz` のみ、DB なし）

```bash
cd infra
terraform apply -var="image_tag=$SHA"      # enable_db は既定の false
```

### ステップ 2B: DB あり（MySQL read/write 確認）

```bash
cd infra
export TF_VAR_db_password='<好きな強いパスワード>'   # tfvars に書かない
terraform apply -var="enable_db=true" -var="image_tag=$SHA"
```

RDS は作成完了まで数分かかる。タスクが接続に失敗する場合は少し待って再確認する。

### ステップ 3: 動作確認

実行中タスクのパブリック IP を取得する（ALB が無いのでタスクの IP を直接叩く）:

```bash
TASK_ARN=$(aws ecs list-tasks --cluster gin-ecs-cheap --service-name gin-ecs-cheap \
  --desired-status RUNNING --query 'taskArns[0]' --output text --region ap-northeast-1)
ENI=$(aws ecs describe-tasks --cluster gin-ecs-cheap --tasks "$TASK_ARN" \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value | [0]" \
  --output text --region ap-northeast-1)
IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI" \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text --region ap-northeast-1)
echo "IP = $IP"
```

ヘルスチェック:

```bash
curl --fail "http://$IP:8080/healthz"          # -> {"status":"ok"}
```

read/write 確認（`enable_db=true` のとき。作成・一覧のみで更新・削除はない）:

```bash
# 作成
curl -s -X POST "http://$IP:8080/items" \
  -H "Content-Type: application/json" \
  -d '{"name":"first item"}'                    # -> {"id":1,"name":"first item"}

# 一覧
curl -s "http://$IP:8080/items"                 # -> [{"id":1,"name":"first item"}, ...]
```

ログ確認（起動やエラーの切り分け）:

```bash
aws logs tail /ecs/gin-ecs-cheap --since 5m --region ap-northeast-1
# "listening on :8080" が出ていれば起動OK
# "exec format error" が出たらイメージが amd64 でない（Dockerfileで固定済みなので通常起きない）
# "database initialization failed" が出たら DB 接続の問題
```

### ステップ 4: 片付け（必ず実行）

**apply 時に付けた `-var` は destroy 時にも同じものを付ける。** 特に DB を有効にした場合は
`-var="enable_db=true"` を付けないと、RDS 等だけ削除して ECS が残る中途半端な差分になる。

```bash
cd infra
# skeleton（DBなし）で立てた場合
terraform destroy

# DB ありで立てた場合
terraform destroy -var="enable_db=true"
```

destroy 後の確認:

```bash
terraform state list        # 空なら Terraform 管理リソースは全て削除済み
```

## CI/CD（GitHub Actions）

ワークフローは CI と CD で分割している。

- `.github/workflows/ci.yml`: `master` への PR で実行（失敗でブロック）
  1. `gofmt`/`go vet`/`golangci-lint`
  2. `go test`
  3. `gitleaks`（secret scan）
  4. `terraform fmt/validate`
  5. `tflint`
- `.github/workflows/deploy.yml`: `master` への push で実行
  1. **build:** Docker イメージをビルドし ECR に push（タグ = コミット SHA）
  2. **deploy:** タスク定義の image を差し替えて register → service を update → 安定待ち
  3. **smoke:** 実行中タスクのパブリック IP に `curl --fail .../healthz`

### 必要な設定

- 先に `terraform apply -var="create_github_oidc=true" -var="github_owner=<owner>" -var="github_repo=<repo>"` で OIDC ロールを作成
- 出力された `github_actions_role_arn` を GitHub の **Secrets** に `AWS_DEPLOY_ROLE_ARN` として登録
- 長期アクセスキーは登録しない（OIDC で引き受ける）
- CI/CD を使わずローカルからデプロイするだけなら OIDC は不要（`create_github_oidc=false` のまま）

## トラブルシューティング（動作確認で実際に遭遇したもの）

- **`exec /server: exec format error`** … イメージのアーキ不一致（arm64 を x86 の Fargate で実行）。
  `app/Dockerfile` で amd64 固定済みなので通常は起きないが、独自にビルドし直す際は
  `docker build --platform linux/amd64` を確認。タグを変えて push し直し、`terraform apply -var="image_tag=<新タグ>"`。
- **`tag immutable` で push できない** … 同名タグは上書き不可。タグを変える。
- **タスクが起動と停止を繰り返す** … `aws logs tail /ecs/gin-ecs-cheap --since 10m` で原因を確認。
  停止理由は `aws ecs describe-tasks ... --query 'tasks[0].stoppedReason'`。
- **`/items` が 404** … `enable_db=false`（skeleton モード）で起動している。DB を有効にして再 apply。

## コストの注意

- **使い終わったら必ず `terraform destroy`**（DB ありなら `-var="enable_db=true"` を付ける）。
  RDS を有効にした場合は起動時間とストレージが課金される
- ALB・NAT Gateway を持たないため、常設の固定費は最小。停止中（destroy 済み）ならほぼ 0 円
- ECR に残るイメージにも僅かに課金される。`force_delete` により destroy でリポジトリごと削除される
- Terraform state はローカル（`infra/terraform.tfstate`）。`infra/` ディレクトリを消すと state を
  見失い、AWS 上のリソースが管理外で残り得る。使い捨て運用は同じ場所で apply→destroy を完結させる
