terraform {
  required_version = ">= 1.11.0" # write-only 引数（password_wo / value_wo）と ephemeral 変数に必要

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100" # aws_db_instance.password_wo / aws_ssm_parameter.value_wo を確認済みのバージョン
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "gin-ecs-cheap"
      ManagedBy = "terraform"
      Ephemeral = "true"
    }
  }
}
