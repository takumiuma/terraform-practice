# GitHub Actions（deploy-lambda.yml）→ AWS の OIDC 認証（create_github_oidc=true のときのみ）。
# 長期アクセスキーを GitHub Secrets に置かず、OIDC でロールを引き受ける。
# 信頼ポリシーは当該リポジトリの master ブランチに絞る。
#
# OIDC プロバイダはアカウントに URL ごとに 1 つしか作れない。infra/ 側（create_github_oidc=true）で
# 既に作っている場合は github_oidc_provider_arn にその ARN を渡す。ただし infra/ は使い捨て運用のため、
# infra/ を destroy するとプロバイダも消えてこのロールが使えなくなる。常設の本構成側で作る方が安全。

locals {
  create_oidc_provider = var.create_github_oidc && var.github_oidc_provider_arn == ""
  github_oidc_provider_arn = (
    local.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.github_oidc_provider_arn
  )
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = local.create_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # GitHub OIDC のルート CA サムプリント（プロバイダが検証に使用）
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_assume" {
  count = var.create_github_oidc ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # repo/branch に厳格に絞る（ワイルドカードを避ける）
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/master"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  count              = var.create_github_oidc ? 1 : 0
  name               = "${local.name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_assume[0].json
}

# コード更新 + スモークテストに必要な権限だけを、この関数に限定して許可
data "aws_iam_policy_document" "github_actions" {
  count = var.create_github_oidc ? 1 : 0

  statement {
    sid = "LambdaDeploy"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionUrlConfig",
    ]
    resources = [aws_lambda_function.api.arn]
  }

  # スモークテスト（署名付きで /healthz を呼ぶ）
  statement {
    sid       = "SmokeTestInvoke"
    actions   = ["lambda:InvokeFunctionUrl"]
    resources = [aws_lambda_function.api.arn]
    condition {
      test     = "StringEquals"
      variable = "lambda:FunctionUrlAuthType"
      values   = ["AWS_IAM"]
    }
  }
}

resource "aws_iam_role_policy" "github_actions" {
  count  = var.create_github_oidc ? 1 : 0
  name   = "${local.name}-github-actions"
  role   = aws_iam_role.github_actions[0].id
  policy = data.aws_iam_policy_document.github_actions[0].json
}
