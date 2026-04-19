terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  alias   = "hub"
  region  = var.aws_region
  profile = var.hub_profile

  assume_role {
    role_arn = var.hub_role_arn
  }
}

provider "aws" {
  alias   = "consumer"
  region  = var.aws_region
  profile = var.consumer_profile

  assume_role {
    role_arn = var.consumer_role_arn
  }
}
