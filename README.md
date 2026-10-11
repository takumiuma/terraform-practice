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
  DB パスワードは ephemeral 変数 + write-only 引数（`password_wo` / `value_wo`）で渡すため、state / plan に保存されない。
  パスワードを変える場合は `rds.tf` の `password_wo_version` と `value_wo_version` を揃えて上げる（値の変更だけでは差分にならない）
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
- Terraform >= 1.11（write-only 引数を使うため）、Go 1.22+、Docker（ローカルビルド時）、`jq`（CIで使用）
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

> **重要（フラグは毎回同じものを付ける）:** `enable_db` や `create_github_oidc` は、付け忘れた
> apply / destroy で既定値 `false` に戻ったとみなされ、**RDS や OIDC ロールが削除される**。
> 毎回 `-var` を揃えるか、`infra/terraform.tfvars`（自動で読み込まれ、`.gitignore` 済み）に
> 秘密以外のフラグを書いておくと付け忘れを防げる（パスワードは書かず `TF_VAR_db_password` で渡す）。
>
> ```hcl
> # infra/terraform.tfvars（例。コミットされない）
> enable_db          = true
> create_github_oidc = true
> github_owner       = "<owner>"
> github_repo        = "<repo>"
> ```

> **重要（2 回目以降の apply はサービスに自動反映されない）:** タスク定義は CI/CD（deploy.yml）も
> 更新するため、`aws_ecs_service` は `task_definition` の差分を無視している（`infra/ecs.tf`）。
> そのため **既にサービスがある状態で** `image_tag` や `enable_db` を変えて apply すると、新しい
> タスク定義は登録されるが、サービスは古い定義のまま動き続ける。apply 後に次のコマンドで
> 最新のタスク定義へ切り替える:
>
> ```bash
> aws ecs update-service --cluster gin-ecs-cheap --service gin-ecs-cheap \
>   --task-definition gin-ecs-cheap --region ap-northeast-1 >/dev/null
> aws ecs wait services-stable --cluster gin-ecs-cheap --services gin-ecs-cheap --region ap-northeast-1
> ```
>
> （`--task-definition` にファミリー名だけを渡すと、最新の ACTIVE リビジョン＝直前の apply で
> 登録したものが使われる。初回 apply でサービスを新規作成するときは不要）

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

ステップ 2A の後にこれを実行した（サービスが既にある）場合は、DB 接続情報を含む新しいタスク定義が
サービスに反映されないため、上記「2 回目以降の apply」の `aws ecs update-service` を実行する
（実行しないと `/items` が 404 のまま）。

`enable_db=true` の間は、以降のどの apply / destroy でも `TF_VAR_db_password` が必要
（未設定だと validation エラーになる）。

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

# DB ありで立てた場合（validation のため TF_VAR_db_password が必要）
# destroy ではパスワードの値は使われないので、apply 時と別のシェルなら 8 文字以上の任意の値でよい
export TF_VAR_db_password='<apply 時のパスワード or 8文字以上の任意の値>'
terraform destroy -var="enable_db=true"

# OIDC ロールも作っていた場合は、同じく create_github_oidc 等も付ける（terraform.tfvars に書いていれば不要）
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

> **deploy は環境を立てている間だけ成功する:** 普段は `terraform destroy` 済みのため、`master` への
> push で起動した deploy は AWS 認証（OIDC ロールが無い）や ECR push で失敗する。これは想定どおり。
> 環境を `terraform apply` した後に CI/CD でデプロイしたい場合は、失敗した実行を **Re-run** するか、
> Actions 画面から **Run workflow（`workflow_dispatch`）を `master` ブランチで** 実行する。
>
> - OIDC の信頼ポリシーは `refs/heads/master` に限定しているため、`master` 以外のブランチで
>   dispatch すると AWS 認証で失敗する
> - OIDC ロールは名前固定なので、destroy → apply で作り直しても ARN は変わらず、Secrets の
>   `AWS_DEPLOY_ROLE_ARN` は登録し直さなくてよい（`create_github_oidc=true` で apply していること）
> - ECR だけある状態（ステップ 1 の途中など）で走った実行は、イメージ push まで成功して後続で
>   失敗する。同じコミットで再実行すると、タグが IMMUTABLE のため push が `tag immutable` で失敗する。
>   その場合は新しいコミットを `master` に push するか、ECR から該当タグのイメージを削除してから再実行する

### 必要な設定

- 先に `terraform apply -var="create_github_oidc=true" -var="github_owner=<owner>" -var="github_repo=<repo>"` で OIDC ロールを作成
- 以降の apply / destroy でもこの 3 つの `-var` を付け続ける（付け忘れると OIDC ロールが削除される）。
  `infra/terraform.tfvars` に書いておくのが確実（「使い方」の冒頭参照）
- 出力された `github_actions_role_arn` を GitHub の **Secrets** に `AWS_DEPLOY_ROLE_ARN` として登録
- 長期アクセスキーは登録しない（OIDC で引き受ける）
- CI/CD を使わずローカルからデプロイするだけなら OIDC は不要（`create_github_oidc=false` のまま）

## トラブルシューティング（動作確認で実際に遭遇したもの）

- **`exec /server: exec format error`** … イメージのアーキ不一致（arm64 を x86 の Fargate で実行）。
  `app/Dockerfile` で amd64 固定済みなので通常は起きないが、独自にビルドし直す際は
  `docker build --platform linux/amd64` を確認。タグを変えて push し直し、`terraform apply -var="image_tag=<新タグ>"` の後に
  「2 回目以降の apply」の `aws ecs update-service` でサービスに反映する。
- **`tag immutable` で push できない** … 同名タグは上書き不可。タグを変える。
- **タスクが起動と停止を繰り返す** … `aws logs tail /ecs/gin-ecs-cheap --since 10m` で原因を確認。
  停止理由は `aws ecs describe-tasks ... --query 'tasks[0].stoppedReason'`。
- **`/items` が 404** … `enable_db=false`（skeleton モード）のタスク定義で起動している。DB を有効にして再 apply し、
  `aws ecs update-service` で新しいタスク定義をサービスに反映する（apply だけでは切り替わらない）。

## コストの注意

- **使い終わったら必ず `terraform destroy`**（DB ありなら `-var="enable_db=true"` と `TF_VAR_db_password` が必要）。
  RDS を有効にした場合は起動時間とストレージが課金される
- ALB・NAT Gateway を持たないため、常設の固定費は最小。停止中（destroy 済み）ならほぼ 0 円
- ECR に残るイメージにも僅かに課金される。`force_delete` により destroy でリポジトリごと削除される
- Terraform state はローカル（`infra/terraform.tfstate`）。`infra/` ディレクトリを消すと state を
  見失い、AWS 上のリソースが管理外で残り得る。使い捨て運用は同じ場所で apply→destroy を完結させる
