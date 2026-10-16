# lambda-efs-sqlite

Lambda に EFS をマウントし、EFS 上の SQLite を DB として使う、**立てっぱなしで月数百円以内**の
小規模 API 基盤。設計は [`docs/Lambda + EFS + SQLite 構成 設計書.md`](../docs/Lambda%20+%20EFS%20+%20SQLite%20構成%20設計書.md) を参照。

- **アプリ:** ECS 版と同じ Gin ルーター（`app/internal/handler`）を、Lambda 用エントリポイント
  `app/cmd/lambda`（aws-lambda-go-api-proxy）で動かす。DB ドライバは CGO 不要の SQLite（`DB_DRIVER=sqlite`）
- **ランタイム:** `provided.al2023` / arm64 / 256MB / timeout 10 秒 / 予約同時実行 1
- **公開:** Function URL（`AWS_IAM` 認証。SigV4 署名のないリクエストは 403）
- **ネットワーク:** VPC + プライベートサブネット ×2。IGW / NAT Gateway / VPC エンドポイントなし
  （Lambda の通信先は EFS の TCP 2049 のみ。ログは Lambda サービス経由で CloudWatch Logs へ）
- **コード更新:** 初回作成は Terraform、以降は CD（`.github/workflows/deploy-lambda.yml`）。
  Terraform 側は `ignore_changes = [filename, source_code_hash]` でコードの差分を無視する
- **state:** ローカル（このディレクトリ内）。コミットしない（`.gitignore` 済み）

## エンドポイント

| メソッド | パス | 成功時 | エラー |
| --- | --- | --- | --- |
| GET | `/healthz` | 200 `{"status":"ok"}` | ― |
| GET | `/items` | 200 items の配列（id 昇順） | ― |
| POST | `/items` | 201 `{"id","name","created_at"}`（ボディ `{"name":"..."}`） | 400：name が空 / JSON 不正 |
| DELETE | `/items/{id}` | 200 `{"deleted": id}` | 400：id が数値でない、404：該当なし |
| その他 | その他 | ― | 404 `{"error":"not found"}` |

## 前提

- Terraform >= 1.11、AWS CLI v2、Go 1.22+（初回ビルド用）、curl 7.75 以上（SigV4 署名対応）

## デプロイ（初回）

```sh
cd lambda-efs-sqlite
./build.sh            # app/cmd/lambda を arm64 でビルド → build/bootstrap
terraform init
terraform apply
```

`build/bootstrap` が無いと plan / apply が `archive_file` のエラーで失敗する。先に `./build.sh` を実行すること。

> **予約同時実行で apply が失敗する場合:** 作りたてのアカウントは同時実行上限が 10 で、
> 予約すると未予約枠が下限を割り失敗する。`-var="reserved_concurrency=-1"` で回避できるが、
> 同時書き込みで SQLite が壊れるリスクが残る。Service Quotas で上限緩和を申請するのが本筋。

## コード更新

- **CD（推奨）:** `master` への push（`app/**` 等が変わったとき）で `deploy-lambda.yml` が
  ビルド → `update-function-code` → 署名付き `/healthz` スモークを行う。設定は下記「CD の設定」
- **手動:** `./build.sh && (cd build && zip -j lambda.zip bootstrap)` の後に
  `aws lambda update-function-code --function-name lambda-efs-sqlite-api --zip-file fileb://build/lambda.zip`
  （`terraform apply` ではコードは更新されない）

## 動作確認

curl の SigV4 署名機能で Function URL を呼ぶ。SSO プロファイルの場合は一時クレデンシャルを環境変数に出す。

```sh
URL=$(terraform output -raw function_url)
eval "$(aws configure export-credentials --format env)"

SIG=(--aws-sigv4 "aws:amz:ap-northeast-1:lambda" \
     --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
     -H "x-amz-security-token: $AWS_SESSION_TOKEN")

curl "${SIG[@]}" -X POST "${URL}items" \
  -H "Content-Type: application/json" -d '{"name":"はじめてのアイテム"}'   # -> 201
curl "${SIG[@]}" "${URL}items"                                              # -> 200
curl "${SIG[@]}" -X DELETE "${URL}items/1"                                  # -> 200
curl -i "${URL}items"                                                       # 署名なし -> 403
```

長期アクセスキーの場合、`x-amz-security-token` ヘッダーは不要。
初回（コールドスタート）は VPC + EFS マウントのため数百ミリ秒〜1 秒程度かかる。

ログ確認:

```sh
aws logs tail /aws/lambda/lambda-efs-sqlite-api --since 10m --region ap-northeast-1
# "database initialization failed" が出たら EFS のマウント / 権限の問題
```

## CD の設定（GitHub Actions）

1. OIDC ロールを作成（以降の apply / destroy でも同じ `-var` を付け続けるか `terraform.tfvars` に書く）

   ```sh
   terraform apply -var="create_github_oidc=true" \
     -var="github_owner=<owner>" -var="github_repo=<repo>"
   ```

2. 出力 `github_actions_role_arn` を GitHub の **Secrets** に `AWS_LAMBDA_DEPLOY_ROLE_ARN` として登録

> **OIDC プロバイダの重複に注意:** GitHub の OIDC プロバイダはアカウントに 1 つしか作れない。
> `infra/`（ECS 版）を `create_github_oidc=true` で立てている場合は、どちらか一方でしか作れないため、
> 既存の ARN を `-var="github_oidc_provider_arn=<ARN>"` で渡す。ただし `infra/` は使い捨て運用なので、
> `infra/` を destroy するとプロバイダも消えてこちらの CD が動かなくなる。**常設の本構成側でプロバイダを作り、
> `infra/` は `create_github_oidc=false` で使う**のが安全（`infra/` の CD も使う場合はその限りでない）。

信頼ポリシーは `refs/heads/master` に限定しているため、`master` 以外のブランチで dispatch すると AWS 認証で失敗する。
ロールの権限はこの関数のコード更新・設定取得・Function URL 呼び出し（スモーク用）だけ。

## コストの注意（固定費の原因になるもの）

常時稼働時の固定費は EFS のストレージ容量課金のみ。次のものは追加しない。

- NAT Gateway（これだけで月数千円）
- Interface 型 VPC エンドポイント（1 つあたり月千円前後。S3 / DynamoDB の Gateway 型は無料なので必要なら可）
- EFS の provisioned スループット
- 保持期間無期限のロググループ
- RDS、ElastiCache、ALB など時間課金のリソース

## 制約

- **同時実行 1:** SQLite on EFS（NFS）は複数の実行環境からの同時書き込みで壊れうるため、予約同時実行を 1 に固定。
  リクエストは直列処理になる。DB 接続はコールドスタート時に 1 本だけ開き、journal は DELETE（WAL は使わない）、
  ロック待ちは `busy_timeout=5000`
- **外部通信不可:** NAT がないため外部 API は呼べない
- **バックアップなし:** 重要データを置く段階で `aws_efs_backup_policy` を有効化する（AWS Backup の料金が発生）

## destroy 時の注意

```sh
terraform destroy   # create_github_oidc 等を付けて apply した場合は同じ -var を付ける
```

- Lambda の ENI（Hyperplane ENI）の解放待ちで、サブネットと SG の削除に数十分かかることがある。タイムアウトしたら再実行する
- destroy すると EFS ごと SQLite のデータが消える。残したい場合は事前に退避する
