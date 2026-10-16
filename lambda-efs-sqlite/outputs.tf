output "function_url" {
  description = "Function URL（IAM 認証。SigV4 署名付きで呼ぶ）"
  value       = aws_lambda_function_url.api.function_url
}

output "function_name" {
  description = "Lambda 関数名（CD のデプロイ先）"
  value       = aws_lambda_function.api.function_name
}

output "github_actions_role_arn" {
  description = "GitHub Secrets AWS_LAMBDA_DEPLOY_ROLE_ARN に登録する IAM ロール ARN（create_github_oidc=true のとき）"
  value       = var.create_github_oidc ? aws_iam_role.github_actions[0].arn : null
}
