# ECS Fargate クラスター / タスク定義 / サービス

resource "aws_ecs_cluster" "main" {
  name = local.name
}

# DB 有効時のみ、コンテナに渡す secrets（SSM 参照）を組み立てる
locals {
  db_secrets = var.enable_db ? [
    { name = "DB_HOST", valueFrom = aws_ssm_parameter.db["host"].arn },
    { name = "DB_PORT", valueFrom = aws_ssm_parameter.db["port"].arn },
    { name = "DB_NAME", valueFrom = aws_ssm_parameter.db["name"].arn },
    { name = "DB_USER", valueFrom = aws_ssm_parameter.db["user"].arn },
    { name = "DB_PASSWORD", valueFrom = aws_ssm_parameter.db["password"].arn },
  ] : []

  container_definitions = jsonencode([
    {
      name      = local.name
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "PORT", value = tostring(var.container_port) }
      ]
      secrets = local.db_secrets
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "app" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = local.container_definitions
}

resource "aws_ecs_service" "app" {
  name            = local.name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = true
  }

  # task_definition は CI/CD 側（deploy.yml）が register-task-definition + update-service で更新するため、
  # Terraform の apply で古い定義に巻き戻さないよう差分を無視する
  lifecycle {
    ignore_changes = [task_definition]
  }
}
