# variables.tf

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "ap-south-1" # Bengaluru, India
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_prefix_length" {
  description = "The prefix length for public subnets (e.g., 8 for /24 based on /16 VPC)."
  type        = number
  default     = 8
}

variable "private_subnet_prefix_length" {
  description = "The prefix length for private subnets."
  type        = number
  default     = 8
}

variable "instance_type" {
  description = "The EC2 instance type for application servers."
  type        = string
  default     = "t3.micro"
}

variable "desired_capacity" {
  description = "The desired number of instances in the Auto Scaling Group."
  type        = number
  default     = 2
}

variable "min_size" {
  description = "The minimum number of instances in the Auto Scaling Group."
  type        = number
  default     = 4
}

variable "max_size" {
  description = "The maximum number of instances in the Auto Scaling Group."
  type        = number
  default     = 4
}

variable "ssh_allowed_cidrs" {
  description = "A list of CIDR blocks that are allowed to SSH into application servers."
  type        = list(string)
  default     = ["192.0.2.0/24"] # Example IP range - REPLACE WITH YOUR ACTUAL IP IN PRODUCTION
}