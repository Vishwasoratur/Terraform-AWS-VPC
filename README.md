# AWS Highly Available Application Deployment with Terraform

This Terraform configuration deploys a highly available and scalable web application infrastructure in AWS, following best practices for cloud deployments. Resources are distributed across multiple Availability Zones to ensure resilience. It also includes an IAM role for EC2 instances to follow the principle of least privilege.

**Important Note on Terraform State Management:**
This configuration uses an S3 bucket and DynamoDB table for remote Terraform state and state locking, respectively. For a real deployment, these backend resources (`highly-available-app-tfstate-bucket-demo-20250727` and `terraform-lock-table-demo`) MUST be provisioned separately (e.g., manually via the AWS Console/CLI, or by a dedicated, minimal Terraform project) *before* running `terraform init` for this main application infrastructure. This project assumes those backend components are already in place.

## Architecture Overview

The deployed architecture includes:

* **Virtual Private Cloud (VPC):** A logically isolated network space in AWS.
* **Multiple Availability Zones:** Resources are spread across two Availability Zones for high availability.
* **Public Subnets:** For internet-facing resources like the Application Load Balancer and NAT Gateways.
* **Private Subnets:** For application servers, ensuring they are not directly accessible from the internet.
* **Internet Gateway (IGW):** Enables communication between the VPC and the internet.
* **NAT Gateways:** Allow instances in private subnets to initiate outbound connections to the internet (e.g., for updates, external APIs) without being publicly accessible.
* **Application Load Balancer (ALB):** Distributes incoming web traffic across multiple application servers.
* **Auto Scaling Group (ASG):** Manages the fleet of application servers, ensuring desired capacity and replacing unhealthy instances. Instances are launched using a Launch Template.
* **Security Groups:** Act as virtual firewalls to control traffic flow to and from the ALB and application servers.
* **IAM Role for EC2 Instances:** Grants specific permissions to application servers (e.g., read from S3, send logs to CloudWatch, use SSM).
* **VPC Endpoint for S3 (Gateway Type):** Provides secure and private access to S3 from instances within the VPC, bypassing the internet.

## Prerequisites

* **AWS Account:** You need an AWS account with appropriate permissions.
* **AWS CLI Configured:** Ensure your AWS CLI is configured with credentials (e.g., `aws configure`).
* **Terraform Installed:** [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli).
* **Backend Resources Created:** The S3 bucket (`highly-available-app-tfstate-bucket-demo-20250727`) and DynamoDB table (`terraform-lock-table-demo`) for Terraform state must exist in your AWS account prior to using this configuration.

## Usage (For Demonstration / Learning)

1.  **Clone this repository** or create the directory structure and files as described.
2.  **Navigate to the project root** directory in your terminal.
3.  **Ensure your backend S3 bucket and DynamoDB table exist** in AWS.
4.  **Initialize Terraform:**
    ```bash
    terraform init
    ```
5.  **Review the plan (optional but recommended):**
    ```bash
    terraform plan
    ```
    This command shows you what resources Terraform will create, modify, or destroy.
6.  **Apply the configuration:**
    ```bash
    terraform apply
    ```
    Type `yes` when prompted to confirm the deployment.
7.  **Access the application:**
    After `terraform apply` completes, the `alb_dns_name` output will provide the URL for your application. Open this URL in your web browser. You should see "Hello from..." from one of your Nginx servers.

## Customization

You can customize the deployment by modifying the `variables.tf` file or by creating a `terraform.tfvars` file (recommended).

### Example `terraform.tfvars` file:

```terraform
# terraform.tfvars
# This file provides default values for variables.
# It should typically be excluded from version control for sensitive data.

aws_region        = "ap-south-1"
instance_type     = "t3.medium"
ssh_allowed_cidrs = ["203.0.113.42/32"] # Replace with your actual public IP or restricted range