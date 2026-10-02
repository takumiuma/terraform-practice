# RDS for MySQL（Bolt2、enable_db=true のときのみ作成）。
# 最安・使い捨て: t4g.micro / Single-AZ / 最小ストレージ / 最終スナップショットなし / 非公開。

# RDS 用セキュリティグループ: ECS タスク SG からの 3306 のみ許可
resource "aws_security_group" "db" {
  count       = var.enable_db ? 1 : 0
  name        = "${local.name}-db-sg"
  description = "gin-ecs-cheap RDS MySQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from ECS task only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.task.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-db-sg" }
}

resource "aws_db_subnet_group" "db" {
  count      = var.enable_db ? 1 : 0
  name       = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.public[*].id
}

resource "aws_db_instance" "mysql" {
  count                       = var.enable_db ? 1 : 0
  identifier                  = local.name
  engine                      = "mysql"
  engine_version              = "8.0"
  instance_class              = var.db_instance_class
  allocated_storage           = var.db_allocated_storage
  storage_type                = "gp3"
  db_name                     = var.db_name
  username                    = var.db_username
  password                    = var.db_password
  db_subnet_group_name        = aws_db_subnet_group.db[0].name
  vpc_security_group_ids      = [aws_security_group.db[0].id]
  multi_az                    = false
  publicly_accessible         = false
  skip_final_snapshot         = true
  deletion_protection         = false
  apply_immediately           = true
  backup_retention_period     = 0
  allow_major_version_upgrade = false
}

# DB 接続情報を SSM Parameter Store（SecureString）に格納。ECS が secrets で参照。
resource "aws_ssm_parameter" "db" {
  for_each = var.enable_db ? {
    host     = aws_db_instance.mysql[0].address
    port     = tostring(aws_db_instance.mysql[0].port)
    name     = var.db_name
    user     = var.db_username
    password = var.db_password
  } : {}

  name  = "/${local.name}/db/${each.key}"
  type  = "SecureString"
  value = each.value
}
