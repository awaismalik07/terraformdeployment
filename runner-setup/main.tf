terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
terraform {
  backend "s3" {
    bucket         = "awais-terraform-state-bucket"
    key            = "runner/terraform.tfstate"     
    region         = "us-east-1"           
    dynamodb_table = "terraform-locks"                
    encrypt        = true                     
  }
}

# --------------------------
# Networking
# --------------------------
resource "aws_vpc" "awais_runner_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "awais-runner-vpc"
  }
}

resource "aws_subnet" "awais_runner_subnet" {
  vpc_id                  = aws_vpc.awais_runner_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "awais-runner-subnet"
  }
}

resource "aws_internet_gateway" "awais_runner_igw" {
  vpc_id = aws_vpc.awais_runner_vpc.id

  tags = {
    Name = "awais-runner-igw"
  }
}

# --------------------------
# Route Table
# --------------------------
resource "aws_route_table" "awais_public_rt" {
  vpc_id = aws_vpc.awais_runner_vpc.id

  tags = {
    Name = "awais-public-rt"
  }
}

# --------------------------
# Route
# --------------------------
resource "aws_route" "awais_public_inet_route" {
  route_table_id         = aws_route_table.awais_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.awais_runner_igw.id
}

# --------------------------
# Route Table Association
# --------------------------
resource "aws_route_table_association" "awais_subnet_association" {
  subnet_id      = aws_subnet.awais_runner_subnet.id
  route_table_id = aws_route_table.awais_public_rt.id
}

# --------------------------
# Security Group
# --------------------------
resource "aws_security_group" "awais_runner_sg" {
  name        = "awais-runner-sg"
  description = "Security group for GitHub Actions EC2 runner"
  vpc_id      = aws_vpc.awais_runner_vpc.id

  tags = {
    Name = "awais-runner-sg"
  }
}

# --------------------------
# Security Group Rules
# --------------------------

# Allow SSH
resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.awais_runner_sg.id
}

# Allow HTTP
resource "aws_security_group_rule" "allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.awais_runner_sg.id
}

# Allow HTTPS
resource "aws_security_group_rule" "allow_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.awais_runner_sg.id
}

# Allow all egress
resource "aws_security_group_rule" "allow_all_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.awais_runner_sg.id
}


# --------------------------
# IAM Role + Policy
# --------------------------
resource "aws_iam_role" "awais_runner_role" {
  name = "AwaisRunnerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach full access policy (admin-style)
resource "aws_iam_role_policy" "awais_runner_policy" {
  name = "AwaisRunnerPolicy"
  role = aws_iam_role.awais_runner_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "rds:*",
          "secretsmanager:*",
          "autoscaling:*",
          "elasticloadbalancing:*",
          "cloudwatch:*",
          "route53:*",
          "acm:*",
          "s3:*",
          "dynamodb:*",
          "iam:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "awais_runner_instance_profile" {
  name = "AwaisRunnerInstanceProfile"
  role = aws_iam_role.awais_runner_role.name
}

# --------------------------
# EC2 Instance
# --------------------------
resource "aws_instance" "awais_runner_ec2" {
  ami                         = "ami-0360c520857e3138f"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.awais_runner_subnet.id
  vpc_security_group_ids      = [aws_security_group.awais_runner_sg.id]
  associate_public_ip_address = true
  key_name                    = "awais-kp" 

  iam_instance_profile = aws_iam_instance_profile.awais_runner_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y curl unzip zip jq git

              # Create runner dir
              mkdir -p /home/ubuntu/actions-runner && cd /home/ubuntu/actions-runner
              curl -o actions-runner-linux-x64-2.308.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.308.0/actions-runner-linux-x64-2.308.0.tar.gz
              tar xzf ./actions-runner-linux-x64-2.308.0.tar.gz

              # Get GitHub registration token
              GH_TOKEN="YOUR_GH_PAT"   # store this in GitHub Secrets and inject via TF
              REG_TOKEN=$(curl -sX POST -H "Authorization: token $GH_TOKEN" \
                https://api.github.com/repos/awaismalik07/terraformdeployment/actions/runners/registration-token | jq -r .token)

              ./config.sh --url https://github.com/awaismalik07/terraformdeployment \
                          --token $REG_TOKEN --unattended --replace

              ./svc.sh install
              ./svc.sh start
              EOF


  tags = {
    Name = "awais-runner-ec2"
  }
}
