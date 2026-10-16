# lambda-efs-sqlite: Lambda + EFS 上の SQLite で動く、立てっぱなし前提の小規模 API 基盤。
# アプリは app/ の Gin ルーターを共通利用する（エントリポイントは app/cmd/lambda）。
# 固定費の原因になる IGW / NAT Gateway / Interface 型 VPC エンドポイントは作らない。

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = var.project
  # 先頭 2 つの AZ を使う（最小構成）
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# ---------------------------------------------------------------------------
# ネットワーク: VPC + プライベートサブネット（外への経路なし）
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = local.azs[count.index]

  tags = { Name = "${local.name}-private-${count.index}" }
}

# ---------------------------------------------------------------------------
# セキュリティグループ
# ---------------------------------------------------------------------------
# 互いの SG を参照するため、ルールは SG 本体から分けて定義する（循環参照の回避）。
# インラインルールを持たない aws_security_group は、AWS 既定の全許可 egress を Terraform が削除する。
resource "aws_security_group" "lambda" {
  name        = "${local.name}-lambda-sg"
  description = "Lambda function (egress to EFS only)"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-lambda-sg" }
}

resource "aws_security_group" "efs" {
  name        = "${local.name}-efs-sg"
  description = "EFS mount targets (NFS from Lambda only)"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-efs-sg" }
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_efs" {
  security_group_id            = aws_security_group.lambda.id
  description                  = "NFS to EFS"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_security_group.efs.id
}

resource "aws_vpc_security_group_ingress_rule" "efs_from_lambda" {
  security_group_id            = aws_security_group.efs.id
  description                  = "NFS from Lambda"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_security_group.lambda.id
}

# ---------------------------------------------------------------------------
# EFS: SQLite ファイルの置き場所
# ---------------------------------------------------------------------------
resource "aws_efs_file_system" "data" {
  encrypted        = true # 保存時暗号化（AWS 管理キー）
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic" # provisioned にしない（固定費になる）

  tags = { Name = "${local.name}-efs" }
}

resource "aws_efs_mount_target" "data" {
  count           = length(aws_subnet.private)
  file_system_id  = aws_efs_file_system.data.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# Lambda は POSIX ユーザー 1000:1000 で /lambda 配下だけを見る
resource "aws_efs_access_point" "lambda" {
  file_system_id = aws_efs_file_system.data.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/lambda"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "750"
    }
  }

  tags = { Name = "${local.name}-ap" }
}

# ---------------------------------------------------------------------------
# IAM: Lambda 実行ロール
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# VPC 内で動くための ENI 作成 + CloudWatch Logs への書き込み
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# EFS へのマウント・書き込みを、このアクセスポイント経由に限定して許可
data "aws_iam_policy_document" "lambda_efs" {
  statement {
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
    ]
    resources = [aws_efs_file_system.data.arn]

    condition {
      test     = "StringEquals"
      variable = "elasticfilesystem:AccessPointArn"
      values   = [aws_efs_access_point.lambda.arn]
    }
  }
}

resource "aws_iam_role_policy" "lambda_efs" {
  name   = "${local.name}-lambda-efs"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_efs.json
}

# ---------------------------------------------------------------------------
# Lambda + Function URL
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name}-api"
  retention_in_days = var.log_retention_days
}

# 初回作成用のコード。事前に ./build.sh で build/bootstrap を作っておく。
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/build/bootstrap"
  output_path = "${path.module}/build/lambda.zip"
}

resource "aws_lambda_function" "api" {
  function_name = "${local.name}-api"
  role          = aws_iam_role.lambda.arn

  # app/cmd/lambda の Go バイナリ（bootstrap）を OS 専用ランタイムで動かす
  runtime       = "provided.al2023"
  handler       = "bootstrap"
  architectures = ["arm64"]
  memory_size   = 256
  timeout       = 10

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  # SQLite on EFS の同時書き込みを防ぐため、実行環境を 1 つに絞る
  reserved_concurrent_executions = var.reserved_concurrency

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  file_system_config {
    arn              = aws_efs_access_point.lambda.arn
    local_mount_path = "/mnt/data"
  }

  environment {
    variables = {
      DB_DRIVER = "sqlite"
      DB_PATH   = "/mnt/data/app.db"
    }
  }

  # マウントターゲットが未完成だと関数作成が失敗する。ロググループと権限も先に用意する
  depends_on = [
    aws_efs_mount_target.data,
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy.lambda_efs,
  ]

  # コードの更新は CD（deploy-lambda.yml）が行うため、Terraform は初回作成のみ担当する。
  # （これがないと、CD でデプロイした後の apply がローカルのビルドで上書きしてしまう）
  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

# IAM 認証（SigV4 署名必須）。同一アカウントの IAM プリンシパルのみ呼べる。リソースポリシーは追加しない
resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "AWS_IAM"
}
