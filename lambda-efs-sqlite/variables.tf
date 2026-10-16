variable "region" {
  description = "AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project" {
  description = "リソース名の接頭辞に使うプロジェクト名"
  type        = string
  default     = "lambda-efs-sqlite"
}

variable "reserved_concurrency" {
  description = "Lambda の予約同時実行数。SQLite on EFS の同時書き込みを防ぐため 1。アカウントの同時実行上限が小さく apply が失敗する場合は -1（予約なし。同時書き込みリスクは残る）"
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch Logs の保持日数"
  type        = number
  default     = 14
}

# --- CI/CD OIDC 関連 ---
variable "create_github_oidc" {
  description = "GitHub Actions（deploy-lambda.yml）用の IAM ロールを作成するか"
  type        = bool
  default     = false
}

variable "github_owner" {
  description = "GitHub のオーナー（ユーザー名または組織名）。OIDC 信頼ポリシーの絞り込みに使う"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub リポジトリ名。OIDC 信頼ポリシーの絞り込みに使う"
  type        = string
  default     = ""
}

variable "github_oidc_provider_arn" {
  description = "既存の GitHub OIDC プロバイダの ARN。空なら本構成で作成する（プロバイダはアカウントに URL ごとに 1 つしか作れない）"
  type        = string
  default     = ""
}
