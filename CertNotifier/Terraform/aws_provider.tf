terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.11"
    }
  }
}
provider "aws" {
  region = "${var.provider_region}"
}
