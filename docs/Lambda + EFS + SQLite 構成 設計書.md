# Lambda + EFS + SQLite 構成 設計書

Oct 15, 2026 · @Takuma Kitano

## 概要・目的

Lambda に EFS をマウントし、EFS 上の SQLite を RDB 代わりに使う、立てっぱなしで月数百円以内に収まる小規模 API 基盤を Terraform で構築する。

以前の ECS + RDS 構成は固定費が大きく、使うたびに apply / destroy する運用だった。本構成は固定費をほぼゼロにし、常時稼働させたままにできることを目的とする。

- 対象：社内ツール程度の小規模・低トラフィックなシステム
- 成果物：Terraform 一式 + Go（Gin）の Lambda（items の一覧・追加・削除 API）+ CD ワークフロー
- リージョン：ap-northeast-1（東京）
- 前提ツール：Terraform 1.11 以上、AWS CLI v2、Go 1.22 以上、curl 7.75 以上（SigV4 署名対応）

## 全体アーキテクチャ

&#91;embedded content: 構成図 · リクエストの流れ\]

リクエストは Function URL で IAM 署名を検証され、VPC 内の Lambda が NFS で EFS 上の SQLite を読み書きする。VPC から外への経路はなく、ログだけが Lambda サービス経由で CloudWatch Logs に出る。

## AWSリソース設計

全リソースに `default_tags` で `Project = var.project`、`ManagedBy = terraform` を付与する。名前の接頭辞は `var.project`（既定値 `lambda-efs-sqlite`）。

| リソース | Terraform 型 | 主な設定 |
| --- | --- | --- |
| VPC | aws\_vpc | CIDR 10.0.0.0/16、DNS サポート・ホスト名を有効化 |
| プライベートサブネット ×2 | aws\_subnet | cidrsubnet(VPC, 8, 0/1)。利用可能な AZ の先頭 2 つに配置 |
| Lambda 用 SG | aws\_security\_group | egress：EFS 用 SG 宛て TCP 2049 のみ。それ以外の通信は不可 |
| EFS 用 SG | aws\_security\_group | ingress：Lambda 用 SG から TCP 2049 のみ |
| EFS | aws\_efs\_file\_system | encrypted = true、generalPurpose、throughput\_mode = elastic |
| マウントターゲット ×2 | aws\_efs\_mount\_target | 各プライベートサブネットに 1 つ、EFS 用 SG を付与 |
| アクセスポイント | aws\_efs\_access\_point | posix\_user 1000:1000、ルート /lambda（owner 1000:1000、権限 750） |
| IAM ロール | aws\_iam\_role | 信頼元 lambda.amazonaws.com |
| VPC 実行権限 | aws\_iam\_role\_policy\_attachment | AWSLambdaVPCAccessExecutionRole（ENI 作成 + Logs） |
| EFS 権限 | aws\_iam\_role\_policy | ClientMount / ClientWrite。条件でアクセスポイント ARN に限定 |
| ロググループ | aws\_cloudwatch\_log\_group | /aws/lambda/\<project>-api、保持 14 日 |
| Lambda | aws\_lambda\_function | provided.al2023（Go バイナリ bootstrap）、arm64、256MB、timeout 10 秒、予約同時実行 1、EFS を /mnt/data にマウント。コードの差分は ignore\_changes（CD が更新） |
| Function URL | aws\_lambda\_function\_url | authorization\_type = AWS\_IAM |
| GitHub OIDC（任意） | aws\_iam\_openid\_connect\_provider / aws\_iam\_role | create\_github\_oidc = true のとき。CD 用。権限は対象関数のコード更新・取得・Function URL 呼び出しのみ |

作らないもの：Internet Gateway、NAT Gateway、Interface 型 VPC エンドポイント（いずれも固定費の原因になるため）。

Lambda は `depends_on` でマウントターゲット・ロググループ・IAM ポリシーの作成完了を待つ。マウントターゲットが未完成だと関数作成が失敗するため。

変数と出力は次のとおり。

| 名前 | 種別 | 既定値・内容 |
| --- | --- | --- |
| region | 変数 | ap-northeast-1 |
| project | 変数 | lambda-efs-sqlite |
| reserved\_concurrency | 変数 | 1（apply が失敗する場合は -1） |
| log\_retention\_days | 変数 | 14 |
| create\_github\_oidc | 変数 | false（true で CD 用 OIDC ロールを作成） |
| github\_owner / github\_repo | 変数 | OIDC 信頼ポリシーの絞り込み（master ブランチ限定） |
| github\_oidc\_provider\_arn | 変数 | 空なら OIDC プロバイダを作成。既存があればその ARN |
| function\_url | 出力 | Function URL |
| function\_name | 出力 | Lambda 関数名 |
| github\_actions\_role\_arn | 出力 | GitHub Secrets `AWS_LAMBDA_DEPLOY_ROLE_ARN` に登録するロール ARN |

Terraform・AWS プロバイダのバージョンは既存の `infra/` に揃える（Terraform >= 1.11、aws \~> 5.100、archive \~> 2.4）。

## アプリケーション設計

ECS 版（`app/`）の Gin ルーター（`app/internal/handler`）を共通利用し、二重実装を避ける。
Lambda 用のエントリポイント `app/cmd/lambda` を追加し、`aws-lambda-go` + `aws-lambda-go-api-proxy/gin`（`ginadapter.NewV2`）で
Function URL のイベント（payload v2.0）を Gin に渡す。SQLite ドライバは CGO 不要の `github.com/glebarez/sqlite`（GORM / modernc.org/sqlite）を使い、
ECS 版と同じく `CGO_ENABLED=0` の静的バイナリとする。ビルドは `lambda-efs-sqlite/build.sh`（GOOS=linux / GOARCH=arm64、出力 `build/bootstrap`）。

Python ではなく Go を選んだ理由：ルーター・モデル・テスト・lint・CI を ECS 版と 1 本化でき、Lambda で追加した DELETE なども両構成で使えるため。

DB は環境変数で切り替える。Lambda では `DB_DRIVER=sqlite`、`DB_PATH=/mnt/data/app.db` を渡す（`DB_DRIVER` が sqlite 以外なら従来どおり MySQL）。

### DB 接続の方針

- コールドスタート時に 1 回だけ開き、ウォーム実行間で使い回す（予約同時実行 1 のため実行環境は 1 つ）
- コネクションプールは `SetMaxOpenConns(1)` で 1 本に絞る
- `busy_timeout=5000` でロック待ちを 5 秒まで許容する
- ジャーナルモードはデフォルト（DELETE）のまま。WAL は共有メモリを使うため NFS 上では使わない
- 起動時に GORM の AutoMigrate でテーブルを作る

### スキーマ

GORM の `Item` モデル（ECS 版と共通）から AutoMigrate で作る。SQLite では概ね次の DDL になる。

```sql
CREATE TABLE IF NOT EXISTS items (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    name       TEXT NOT NULL,
    created_at DATETIME
);
```

### API 仕様

ルーティングは Gin が行う（Function URL のイベントは ginadapter が `http.Request` に変換する）。レスポンスはすべて `Content-Type: application/json`（UTF-8 のまま出力）。項目名は ECS 版の既存 API に合わせて `name` とする。

| メソッド | パス | リクエスト | 成功時 | エラー |
| --- | --- | --- | --- | --- |
| GET | /healthz | なし | 200：`{"status": "ok"}` | なし |
| GET | /items | なし | 200：items の配列（id 昇順） | なし |
| POST | /items | JSON `{"name": "..."}` | 201：`{"id", "name", "created_at"}` | 400：name が空 / JSON 不正 |
| DELETE | /items/{id} | なし | 200：`{"deleted": id}` | 400：id が数値でない、404：該当なし |
| その他 | その他 | ― | ― | 404：`{"error": "not found"}` |

リクエストボディが `isBase64Encoded = true` の場合の base64 デコードは ginadapter が行う。

## セキュリティ設計

Function URL は IAM 認証（AWS\_IAM）とし、SigV4 署名のないリクエストは拒否する。URL が漏れても第三者は呼び出せない。

- **認証**：同一アカウントの IAM ユーザー・ロール（AdministratorAccess 等）からの署名付きリクエストのみ許可。リソースポリシーは追加しない
- **ネットワーク**：Lambda の通信先は EFS（TCP 2049）だけ。インターネットへの経路は存在しない
- **暗号化**：EFS は保存時暗号化を有効にする（AWS 管理キー）
- **最小権限**：EFS への権限はアクセスポイント経由のマウントに限定。アクセスポイントで POSIX ユーザーを 1000:1000 に固定し、/lambda 配下以外は見えない

AWS\_IAM を選んだ理由：認証なし（NONE）の Function URL は、2025 年 10 月以降 lambda:InvokeFunctionUrl と lambda:InvokeFunction の 2 つのリソースポリシーが必要になった。Terraform での書き方が安定しておらず、社内用途なら署名必須のほうが安全なため。

ブラウザから使う必要が出たら、CloudFront + OAC（Origin Access Control）を前段に置く構成に拡張する（本設計の範囲外）。

## コスト設計

常時稼働時の固定費は EFS のストレージ容量課金のみで、小規模利用なら月数百円以内に収まる想定。金額は概算で、最新の料金は AWS の料金ページで確認すること。

| 要素 | 課金の仕方 | 本構成での見込み |
| --- | --- | --- |
| Lambda | リクエスト数 + 実行時間（GB 秒） | 無料枠（月 100 万リクエスト・40 万 GB 秒）内でほぼ 0 円 |
| EFS ストレージ | 保存容量（GB・月） | 数百 MB なら月数十円程度 |
| EFS スループット（Elastic） | 読み書きしたデータ量 | SQLite の小さな読み書きのみで微少 |
| マウントターゲット | なし | 0 円 |
| VPC・サブネット・SG | なし | 0 円 |
| Function URL | なし（Lambda 料金に含まれる） | 0 円 |
| CloudWatch Logs | 取り込み量 + 保存量 | 保持 14 日で微少 |

### 禁止事項（固定費の原因になるもの）

- NAT Gateway を作らない（これだけで月数千円かかる）
- Interface 型 VPC エンドポイントを作らない（1 つあたり月千円前後）。S3 / DynamoDB の Gateway 型は無料なので必要なら可
- EFS のスループットモードを provisioned にしない
- ロググループを保持期間無期限のまま放置しない
- RDS、ElastiCache、ALB など時間課金のリソースを追加しない

## 制約・リスクと対策

最大のリスクは SQLite on EFS の同時書き込みで、Lambda の予約同時実行を 1 にして回避する。

| リスク | 内容 | 対策 |
| --- | --- | --- |
| 同時書き込みによるロック競合・破損 | NFS 上の SQLite はファイルロックが不安定で、複数の実行環境から同時に書くと壊れうる | 予約同時実行を 1 に固定。ロック待ちは timeout=5 秒 |
| 予約同時実行で apply が失敗 | 作りたてのアカウントは同時実行上限が 10 で、予約すると未予約枠が下限を割る | reserved\_concurrency を -1 にして回避（同時書き込みリスクは残る）。上限緩和申請も可 |
| スループットの上限 | 同時実行 1 のため、リクエストは直列処理になる | 社内ツール規模では問題なし。高負荷になったら RDS 等へ移行 |
| コールドスタート | VPC + EFS マウントで初回応答が数百ミリ秒〜1 秒程度遅くなる | 許容する（常時ウォームアップはしない） |
| データ消失 | EFS の自動バックアップは Terraform 作成時は無効 | 重要データを置く段階で aws\_efs\_backup\_policy を有効化（AWS Backup の料金が発生） |
| 外部通信ができない | NAT がないため外部 API を呼べない | 必要になったら VPC 外の別 Lambda に任せる等、NAT 以外の方法を検討 |

## 運用手順

通常は apply したまま常時稼働させ、destroy は構成を捨てるときだけ行う。

### デプロイ

```sh
./build.sh
terraform init
terraform apply
```

Terraform が担当するのは初回のコード配置まで。以降のコード更新は CD（`.github/workflows/deploy-lambda.yml`）が行い、
Terraform 側は `ignore_changes = [filename, source_code_hash]` でコードの差分を無視する（ECS 版の task\_definition と同じ方針）。

### CD（GitHub Actions）

`master` への push（`app/**`、`lambda-efs-sqlite/build.sh`、ワークフロー自身の変更時）と手動実行で動く。

1. `build.sh` で arm64 の bootstrap をビルドして zip 化
2. OIDC でロールを引き受け（Secrets `AWS_LAMBDA_DEPLOY_ROLE_ARN`）
3. `aws lambda update-function-code` → `aws lambda wait function-updated`
4. Function URL の `/healthz` を SigV4 署名付きで呼ぶスモークテスト

GitHub の OIDC プロバイダはアカウントに 1 つしか作れない。`infra/` は使い捨て運用のため、常設の本構成側で作るのを基本とする
（`infra/` で作成済みなら `github_oidc_provider_arn` で既存を渡す）。

### 動作確認

curl の SigV4 署名機能で Function URL を呼ぶ。SSO プロファイルの場合は一時クレデンシャルを環境変数に出す。

```sh
URL=$(terraform output -raw function_url)
eval "$(aws configure export-credentials --format env)"

SIG=(--aws-sigv4 "aws:amz:ap-northeast-1:lambda" \
     --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
     -H "x-amz-security-token: $AWS_SESSION_TOKEN")

curl "${SIG[@]}" -X POST "${URL}items" \
  -H "Content-Type: application/json" -d '{"name":"はじめてのアイテム"}'
curl "${SIG[@]}" "${URL}items"
curl "${SIG[@]}" -X DELETE "${URL}items/1"
```

長期アクセスキーの場合、`x-amz-security-token` ヘッダーは不要。

### destroy 時の注意

- Lambda の ENI（Hyperplane ENI）の解放待ちで、サブネットと SG の削除に数十分かかることがある。タイムアウトしたら再実行する
- destroy すると EFS ごと SQLite のデータが消える。残したい場合は事前に退避する

## 実装タスク一覧と完了条件

下記のファイル構成で実装する。

```text
app/                         # ECS 版と共通の Go アプリ
├── cmd/lambda/main.go       # Lambda 用エントリポイント（ginadapter）
└── internal/handler/        # ルーター（DELETE・NoRoute を追加）、DB（SQLite 対応を追加）、テスト
lambda-efs-sqlite/
├── versions.tf    # Terraform / provider（infra/ と同じバージョン）、default_tags
├── main.tf        # VPC、SG、EFS、IAM、Lambda、Function URL
├── oidc.tf        # CD 用 GitHub OIDC ロール（任意）
├── variables.tf   # region、project、reserved_concurrency ほか
├── outputs.tf     # function_url、function_name、github_actions_role_arn
├── build.sh       # arm64 の bootstrap をビルド
├── .tflint.hcl
├── .gitignore     # .terraform/、*.tfstate*、build/
└── README.md      # デプロイ・動作確認・CD 設定・注意点
.github/workflows/
├── ci.yml             # terraform 検証・tflint の対象に lambda-efs-sqlite を追加、arm64 ビルド確認
└── deploy-lambda.yml  # Lambda の CD
```

### 実装タスク

- [x] provider 設定（infra/ と同じ aws \~> 5.100、archive \~> 2.4、default\_tags）
- [x] VPC とプライベートサブネット 2 つ（IGW・NAT なし）
- [x] Lambda 用 SG と EFS 用 SG、相互参照の 2049 ルール
- [x] EFS（暗号化、Elastic）、マウントターゲット 2 つ、アクセスポイント
- [x] IAM ロール、VPC 実行ポリシー、EFS アクセスポリシー（アクセスポイント条件付き）
- [x] ロググループ（保持 14 日）
- [x] Lambda 関数（VPC 設定、EFS マウント、予約同時実行、depends\_on）
- [x] Function URL（AWS\_IAM）
- [x] Go アプリの共通化（SQLite 対応、DELETE、Lambda エントリポイント、テスト）
- [x] CD ワークフローと OIDC ロール
- [x] variables.tf、outputs.tf、.gitignore、README.md

### 完了条件

- [ ] `terraform validate` と `terraform plan` がエラーなく通る
- [ ] plan に NAT Gateway、Internet Gateway、VPC エンドポイントが含まれない
- [ ] apply 後、POST → GET → DELETE が仕様どおりのステータスコードで返る
- [ ] 署名なしの curl が 403 になる
- [ ] Lambda を再デプロイしても GET で既存データが返る（EFS に永続化されている）
