terraform {
  required_version = ">= 1.11.0" # infra/ と揃える

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100" # infra/ と揃える
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}
