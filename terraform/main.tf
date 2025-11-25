
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project = "nginx-demo"
    Owner   = var.owner
  }
}

# ------------------------------------------------------------------------------
# S3 Bucket (general use / artifacts)
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "nginx_bucket" {
  bucket        = var.s3_bucket_name
  force_destroy = true

  tags = merge(local.common_tags, {
    Name = "nginx-demo-bucket"
  })
}

# ------------------------------------------------------------------------------
# KEY PAIR
# ------------------------------------------------------------------------------
resource "tls_private_key" "nginx_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "nginx_private_key" {
  filename        = "${path.module}/nginx-demo-key.pem"
  content         = tls_private_key.nginx_key.private_key_pem
  file_permission = "0600"
}

resource "aws_key_pair" "nginx_key" {
  key_name   = var.key_name
  public_key = tls_private_key.nginx_key.public_key_openssh

  tags = merge(local.common_tags, {
    Name = var.key_name
  })
}

# ------------------------------------------------------------------------------
# NETWORKING
# ------------------------------------------------------------------------------
resource "aws_vpc" "nginx_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "nginx-vpc"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.nginx_vpc.id

  tags = merge(local.common_tags, {
    Name = "nginx-igw"
  })
}

# Public Subnet (Bastion Only)
resource "aws_subnet" "bastion" {
  vpc_id                  = aws_vpc.nginx_vpc.id
  cidr_block              = var.bastion_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = merge(local.common_tags, {
    Name = "bastion-subnet"
  })
}

# Private Subnet (NGINX)
resource "aws_subnet" "nginx_subnet" {
  vpc_id                  = aws_vpc.nginx_vpc.id
  cidr_block              = var.nginx_subnet_cidr
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}a"

  tags = merge(local.common_tags, {
    Name = "nginx-private-subnet"
  })
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "nginx-nat-eip"
  })
}

resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.bastion.id
  allocation_id = aws_eip.nat.id

  tags = merge(local.common_tags, {
    Name = "nginx-nat-gw"
  })

  depends_on = [aws_internet_gateway.igw]
}

# PUBLIC Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.nginx_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, {
    Name = "nginx-public-rt"
  })
}

resource "aws_route_table_association" "public_bastion" {
  subnet_id      = aws_subnet.bastion.id
  route_table_id = aws_route_table.public.id
}

# PRIVATE Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.nginx_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(local.common_tags, {
    Name = "nginx-private-rt"
  })
}

resource "aws_route_table_association" "private_nginx" {
  subnet_id      = aws_subnet.nginx_subnet.id
  route_table_id = aws_route_table.private.id
}

# ------------------------------------------------------------------------------
# SECURITY GROUPS
# ------------------------------------------------------------------------------
# Bastion SG – Allow SSH from Internet
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH from anywhere"
  vpc_id      = aws_vpc.nginx_vpc.id

  ingress {
    description = "SSH from internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "bastion-sg"
  })
}

# NGINX SG – SSH only from Bastion, HTTP inside VPC
resource "aws_security_group" "nginx_sg" {
  name        = "nginx-sg"
  description = "SG for NGINX instances"
  vpc_id      = aws_vpc.nginx_vpc.id

  ingress {
    description      = "SSH from bastion"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups  = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description = "HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # internal only
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "nginx-sg"
  })
}

# ------------------------------------------------------------------------------
# AMI Lookup
# ------------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ------------------------------------------------------------------------------
# EC2 Instances — Bastion + NGINX
# ------------------------------------------------------------------------------
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_bastion
  subnet_id                   = aws_subnet.bastion.id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.nginx_key.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]

  tags = merge(local.common_tags, {
    Name = "bastion-host"
    Role = "bastion"
  })
}

resource "aws_instance" "nginx_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type_nginx
  subnet_id                   = aws_subnet.nginx_subnet.id
  associate_public_ip_address = false
  key_name                    = aws_key_pair.nginx_key.key_name
  vpc_security_group_ids      = [aws_security_group.nginx_sg.id]

  tags = merge(local.common_tags, {
    Name = "nginx-server"
    Role = "nginx"
  })
}
