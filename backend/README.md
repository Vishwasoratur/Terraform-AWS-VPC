# Terraform Backend Bootstrap Configuration

This Terraform configuration is designed to provision the necessary AWS resources for storing and locking Terraform state files for your main infrastructure projects.

**It should be executed BEFORE your main Terraform project.**

## Resources Created

* **AWS S3 Bucket:** A private S3 bucket with versioning and server-side encryption enabled. This bucket will store your `terraform.tfstate` files, providing a durable, versioned, and secure remote backend.
* **AWS DynamoDB Table:** A DynamoDB table configured for state locking. This prevents concurrent Terraform operations on the same state file, which can lead to state corruption.

## Prerequisites

* **AWS Account:** You need an AWS account with appropriate permissions to create S3 buckets and DynamoDB tables.
* **AWS CLI Configured:** Ensure your AWS CLI is configured with credentials (e.g., `aws configure`).
* **Terraform Installed:** [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli).

## Usage

1.  **Create a new directory** for this bootstrap project (e.g., `backend-bootstrap`).
2.  **Save the `.tf` files** (`main.tf`, `variables.tf`, `outputs.tf`) and this `README.md` into the `backend-bootstrap` directory.
3.  **Review `variables.tf`**: Ensure the `s3_bucket_name` is globally unique. If the default is already taken, you'll need to change it here.
4.  **Navigate to the `backend-bootstrap` directory** in your terminal:
    ```bash
    cd backend-bootstrap
    ```
5.  **Initialize Terraform for this bootstrap project:**
    ```bash
    terraform init
    ```
6.  **Review the plan:**
    ```bash
    terraform plan
    ```
    This will show you the S3 bucket and DynamoDB table that will be created.
7.  **Apply the configuration:**
    ```bash
    terraform apply
    ```
    Type `yes` when prompted to confirm the creation of resources.

Once `terraform apply` completes successfully, your backend S3 bucket and DynamoDB table will be ready for use by your main Terraform projects.

## Clean Up (Optional)

To destroy the backend resources (only if you no longer need them and understand the implications for your main project's state):

```bash
terraform destroy