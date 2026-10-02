variable "region" {
  description = "AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "リソース名の接頭辞に使うプロジェクト名"
  type        = string
  default     = "gin-ecs-cheap"
}

variable "container_port" {
  description = "コンテナ（Gin）がリッスンするポート"
  type        = number
  default     = 8080
}

variable "image_tag" {
  description = "デプロイする ECR イメージのタグ（コミット SHA を渡す。latest 非依存）"
  type        = string
  default     = "bootstrap"
}

variable "task_cpu" {
  description = "Fargate タスクの CPU ユニット（256 = 0.25 vCPU）"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate タスクのメモリ（MiB）"
  type        = number
  default     = 512
}

variable "log_retention_days" {
  description = "CloudWatch Logs の保持日数（低コスト運用のため短め）"
  type        = number
  default     = 3
}

# --- DB（Bolt2）関連。enable_db=false の間は RDS を作らず walking skeleton 構成。 ---
variable "enable_db" {
  description = "RDS(MySQL) を作成するか。false の場合はアプリは /healthz のみの skeleton 構成で動く"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "MySQL のデータベース名"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "MySQL のマスターユーザー名"
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "MySQL のマスターパスワード。tfvars に書かず、環境変数 TF_VAR_db_password で渡す"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = !var.enable_db || length(var.db_password) >= 8
    error_message = "enable_db=true の場合、db_password は8文字以上で指定してください（TF_VAR_db_password で渡す）。"
  }
}

variable "db_instance_class" {
  description = "RDS インスタンスクラス（最安の t4g.micro）"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS の割当ストレージ（GB、最小）"
  type        = number
  default     = 20
}

# --- CI/CD OIDC 関連 ---
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

variable "create_github_oidc" {
  description = "GitHub Actions 用の OIDC プロバイダと IAM ロールを作成するか"
  type        = bool
  default     = false
}
