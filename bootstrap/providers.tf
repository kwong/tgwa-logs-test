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
}

provider "aws" {
  alias   = "consumer"
  region  = var.aws_region
  profile = var.consumer_profile
}
