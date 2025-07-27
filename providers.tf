# providers.tf (Correct structure)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Always good to specify a version
    }
  }

  backend "s3" {
    bucket         = "highly-available-app-tfstate-bucket-demo-20250727" # This bucket name must be globally unique
    key            = "highly-available-app/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table-demo"
  }
}

provider "aws" {
  region = var.aws_region
}