# Data source for Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# 1. IAM Role for EC2 Instances
resource "aws_iam_role" "ec2_instance_role" {
  name = "AppServerEC2Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "AppServerEC2Role"
  }
}

# Attach common AWS managed policies for EC2
resource "aws_iam_role_policy_attachment" "ssm_managed_policy" {
  role        = aws_iam_role.ec2_instance_role.name
  policy_arn  = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" # For Session Manager access
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_managed_policy" {
  role        = aws_iam_role.ec2_instance_role.name
  policy_arn  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" # For sending logs/metrics to CloudWatch
}

# Custom policy for S3 read access (if application needs to read from S3)
resource "aws_iam_policy" "s3_read_policy" {
  name        = "AppServerS3ReadAccess"
  description = "Allows EC2 instances to read from specific S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::your-app-data-bucket/*", # Replace with your actual S3 bucket for application data
          "arn:aws:s3:::your-app-data-bucket",
        ]
      },
    ]
  })

  tags = {
    Name = "AppServerS3ReadPolicy"
  }
}

resource "aws_iam_role_policy_attachment" "s3_read_policy_attachment" {
  role        = aws_iam_role.ec2_instance_role.name
  policy_arn  = aws_iam_policy.s3_read_policy.arn
}


# IAM Instance Profile to attach the role to EC2 instances
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "AppServerEC2InstanceProfile"
  role = aws_iam_role.ec2_instance_role.name

  tags = {
    Name = "AppServerEC2InstanceProfile"
  }
}


# 2. VPC
resource "aws_vpc" "app_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "HighlyAvailableAppVPC"
  }
}

# 3. Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "main-igw"
  }
}

# 4. Public Subnets (at least 2 for high availability)
resource "aws_subnet" "public_subnet" {
  count                   = 2 # Ensure at least 2 AZs are targeted
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.app_vpc.cidr_block, var.public_subnet_prefix_length, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet-${count.index + 1}"
  }
}

# 5. Private Subnets (at least 2 for high availability)
resource "aws_subnet" "private_subnet" {
  count             = 2 # Ensure at least 2 AZs are targeted
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.app_vpc.cidr_block, var.private_subnet_prefix_length, count.index + length(aws_subnet.public_subnet)) # Offset index for private subnets
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "PrivateSubnet-${count.index + 1}"
  }
}

# 6. NAT Gateways (one per public subnet in each AZ)
resource "aws_eip" "nat_gateway_eip" {
  count = length(aws_subnet.public_subnet)
  domain = "vpc" # Corrected from 'vpc = true'
  tags = {
    Name = "nat-gateway-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  count         = length(aws_subnet.public_subnet)
  allocation_id = aws_eip.nat_gateway_eip[count.index].id
  subnet_id     = aws_subnet.public_subnet[count.index].id

  tags = {
    Name = "NATGateway-${count.index + 1}"
  }
  depends_on = [aws_internet_gateway.main_igw]
}

# 7. Route Tables
# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Associate Public Route Table with Public Subnets
resource "aws_route_table_association" "public_rta" {
  count          = length(aws_subnet.public_subnet)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Tables (one per private subnet pointing to its NAT Gateway)
resource "aws_route_table" "private_rt" {
  count  = length(aws_subnet.private_subnet)
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[count.index].id
  }

  tags = {
    Name = "PrivateRouteTable-${count.index + 1}"
  }
}

# Associate Private Route Tables with Private Subnets
resource "aws_route_table_association" "private_rta" {
  count          = length(aws_subnet.private_subnet)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt[count.index].id
}

# 8. Security Groups

# Security Group for the Application Load Balancer
resource "aws_security_group" "alb_sg" {
  vpc_id      = aws_vpc.app_vpc.id
  name        = "alb-sg"
  description = "Allow HTTP/HTTPS traffic to ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB-SecurityGroup"
  }
}

# Security Group for the Application Servers
resource "aws_security_group" "app_server_sg" {
  vpc_id      = aws_vpc.app_vpc.id
  name        = "app-server-sg"
  description = "Allow traffic from ALB and SSH"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AppServer-SecurityGroup"
  }
}

# 9. Application Load Balancer (ALB)
resource "aws_lb" "application_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public_subnet[*].id

  tags = {
    Name = "ApplicationLoadBalancer"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.app_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "AppTargetGroup"
  }
}

# ALB Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.application_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  tags = {
    Name = "HTTPListener"
  }
}

# 10. Auto Scaling Group (ASG)
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

locals {
  user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo amazon-linux-extras install nginx1 -y
    sudo systemctl start nginx
    sudo systemctl enable nginx
    echo "<h1>Hello from $(hostname -f)</h1>" | sudo tee /usr/share/nginx/html/index.html
  EOF
}

# Launch Template for ASG
resource "aws_launch_template" "app_lt" {
  name                   = "app-launch-template"
  image_id               = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app_server_sg.id]
  user_data              = base64encode(local.user_data)
  # Attach the IAM Instance Profile to the Launch Template
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "AppServer"
    }
  }

  tags = { # Tags for the Launch Template itself
    Name = "AppLaunchTemplate"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  name                      = "app-asg"
  vpc_zone_identifier       = aws_subnet.private_subnet[*].id
  desired_capacity          = var.desired_capacity
  min_size                  = var.min_size
  max_size                  = var.max_size
  target_group_arns         = [aws_lb_target_group.app_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  # Use individual 'tag' blocks for tags that should propagate to instances
  tag {
    key                 = "Name"
    value               = "AppServer"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = "Production"
    propagate_at_launch = true
  }
  tag {
    key                 = "Application"
    value               = "HighlyAvailableApp"
    propagate_at_launch = true
  }
}

# 11. VPC Endpoint for S3 (Gateway Type)
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.app_vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private_rt : rt.id]

  tags = {
    Name = "S3VPCEndpoint"
  }
}
