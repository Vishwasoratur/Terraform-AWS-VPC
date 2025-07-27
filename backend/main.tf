# backend-bootstrap/main.tf

# Define the AWS provider for this bootstrap configuration
provider "aws" {
  region = var.aws_region
}

# Resource for the S3 bucket to store Terraform state files (basic bucket creation)
resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = var.s3_bucket_name # Name from variables.tf

  # DO NOT include 'acl' or 'object_ownership' directly here.
  # They are managed by separate dedicated resources.

  tags = {
    Name        = "TerraformStateBucket"
    Environment = "BackendBootstrap"
    ManagedBy   = "Terraform"
  }
}

# New: Resource to enforce bucket ownership, which disables ACLs
resource "aws_s3_bucket_ownership_controls" "terraform_state_bucket_ownership" {
  bucket = aws_s3_bucket.terraform_state_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Removed: aws_s3_bucket_acl is incompatible when BucketOwnerEnforced
# The bucket will no longer allow ACLs because of the ownership controls.
# resource "aws_s3_bucket_acl" "terraform_state_bucket_acl" {
#   bucket = aws_s3_bucket.terraform_state_bucket.id
#   acl    = "private"
# }


# Separate resource to enable S3 bucket versioning
resource "aws_s3_bucket_versioning" "terraform_state_bucket_versioning" {
  # This resource must depend on the bucket and its ownership controls
  # to ensure ownership is set before versioning (implicitly handled by Terraform)
  bucket = aws_s3_bucket.terraform_state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Separate resource to enable S3 bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_bucket_encryption" {
  # This resource must depend on the bucket and its ownership controls
  bucket = aws_s3_bucket.terraform_state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Resource for the DynamoDB table to handle Terraform state locking
resource "aws_dynamodb_table" "terraform_locks_table" {
  name           = var.dynamodb_table_name # Name from variables.tf
  billing_mode   = "PAY_PER_REQUEST"       # Cost-effective for low-frequency locking operations
  hash_key       = "LockID"                # The required primary key for Terraform state locking

  attribute {
    name = "LockID"
    type = "S" # String type for the LockID
  }

  tags = {
    Name        = "TerraformLockTable"
    Environment = "BackendBootstrap"
    ManagedBy   = "Terraform"
  }
}