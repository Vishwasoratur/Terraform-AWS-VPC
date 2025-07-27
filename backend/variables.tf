# backend-bootstrap/variables.tf

variable "aws_region" {
  description = "The AWS region where the backend resources will be created."
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "The globally unique name for the S3 bucket to store Terraform state."
  type        = string
  default     = "highly-available-app-tfstate-bucket-demo-20250727" # Must be globally unique!
}

variable "dynamodb_table_name" {
  description = "The name for the DynamoDB table to manage Terraform state locks."
  type        = string
  default     = "terraform-lock-table-demo" # Consistent with your main project
}