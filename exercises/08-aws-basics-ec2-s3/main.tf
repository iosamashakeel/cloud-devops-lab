terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Latest Amazon Linux 2023 AMI in the chosen region. Using a data source
# instead of a hardcoded AMI id means this works in any region.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Security group: HTTP open to the world (the web page), SSH only from
# the address given in allowed_ssh_cidr. Never open SSH to 0.0.0.0/0.
resource "aws_security_group" "web" {
  name        = "lab-web-sg"
  description = "Allow HTTP from anywhere, SSH only from the lab machine"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "All outbound (package installs, updates)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "lab-web-sg"
    Project = "cloud-devops-lab"
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web.id]
  user_data              = file("${path.module}/user_data.sh")

  tags = {
    Name    = "lab-web"
    Project = "cloud-devops-lab"
  }
}

# Private bucket. Bucket names are globally unique, so the default below
# appends a random suffix — pass your own bucket_name to use a fixed one.
resource "random_pet" "bucket_suffix" {
  length = 2
}

resource "aws_s3_bucket" "lab" {
  bucket        = var.bucket_name != "" ? var.bucket_name : "cloud-devops-lab-${random_pet.bucket_suffix.id}"
  force_destroy = true

  tags = {
    Name    = "cloud-devops-lab"
    Project = "cloud-devops-lab"
  }
}

# Versioning on: overwriting an object keeps the old version recoverable.
resource "aws_s3_bucket_versioning" "lab" {
  bucket = aws_s3_bucket.lab.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Belt and braces: block every form of public access at the account level
# for this bucket, even if a bucket policy is later added by mistake.
resource "aws_s3_bucket_public_access_block" "lab" {
  bucket = aws_s3_bucket.lab.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
