terraform {
  required_version = ">= 1.9.0" # db_password のクロス変数 validation に必要

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
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
