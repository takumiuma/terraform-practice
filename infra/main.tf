# gin-ecs-cheap: Gin(Go) を ECS Fargate 上で最安・使い捨て運用する構成。
# ALB なし・NAT Gateway なし。タスクにパブリック IP を直付けして公開する。

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = var.project_name
  # 先頭 2 つの AZ を使う（最小構成）
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# ---------------------------------------------------------------------------
# ネットワーク: VPC + パブリックサブネット + IGW（NAT Gateway なし）
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-igw" }
}

resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${local.name}-public-${count.index}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# セキュリティグループ
# ---------------------------------------------------------------------------
# ECS タスク用: コンテナポートへのインバウンドを許可、egress は全許可
resource "aws_security_group" "task" {
  name        = "${local.name}-task-sg"
  description = "gin-ecs-cheap ECS task"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "app port from anywhere (learning/throwaway; stop or destroy when unused)"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-task-sg" }
}

# ---------------------------------------------------------------------------
# ECR リポジトリ（scan-on-push 有効、destroy 時にイメージごと削除）
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = local.name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ---------------------------------------------------------------------------
# CloudWatch Logs
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------------------------
# IAM: ECS タスク実行ロール / タスクロール
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${local.name}-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

# ECR pull + CloudWatch Logs 出力の標準ポリシー
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# タスク実行ロールに SSM パラメータ読み取りを許可（DB 秘密の注入用）
data "aws_iam_policy_document" "task_execution_ssm" {
  count = var.enable_db ? 1 : 0
  statement {
    actions   = ["ssm:GetParameters"]
    resources = [for p in aws_ssm_parameter.db : p.arn]
  }
}

resource "aws_iam_role_policy" "task_execution_ssm" {
  count  = var.enable_db ? 1 : 0
  name   = "${local.name}-task-exec-ssm"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.task_execution_ssm[0].json
}

# アプリ実行時のタスクロール（現状追加権限は不要だが枠として作る）
resource "aws_iam_role" "task" {
  name               = "${local.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}
