terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "mlops-workshop-krysha-data1"
    key    = "mlopserver/ecs/default/terraform.tfstate"
    region = "eu-west-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
