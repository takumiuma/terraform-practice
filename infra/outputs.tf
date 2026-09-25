output "ecr_repository_url" {
  description = "ECR リポジトリ URL（CI/CD が push する先）"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS クラスター名"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS サービス名（CI/CD が update-service する対象）"
  value       = aws_ecs_service.app.name
}

output "task_family" {
  description = "ECS タスク定義ファミリー"
  value       = aws_ecs_task_definition.app.family
}

output "log_group" {
  description = "CloudWatch ロググループ"
  value       = aws_cloudwatch_log_group.app.name
}

output "github_actions_role_arn" {
  description = "GitHub Actions が引き受ける IAM ロール ARN（create_github_oidc=true のとき）"
  value       = var.create_github_oidc ? aws_iam_role.github_actions[0].arn : null
}

output "db_endpoint" {
  description = "RDS エンドポイント（enable_db=true のとき）"
  value       = var.enable_db ? aws_db_instance.mysql[0].address : null
}
