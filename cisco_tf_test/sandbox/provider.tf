variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_account_ids" {
  type    = list(string)
  default = null
}

terraform {
   required_version = ">= 0.13.1"
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 3.0"
      }
    }
 
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = var.aws_account_ids
  profile             = "default"
}
