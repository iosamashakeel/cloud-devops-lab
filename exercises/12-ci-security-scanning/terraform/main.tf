# Sample Terraform config for Checkov/tfsec practice.
# It contains ONE deliberate misconfiguration (the open ingress rule)
# for Part 2 of the exercise. Fix it, don't just suppress it.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_security_group" "web" {
  name        = "scan-demo-web"
  description = "Web traffic for the scan demo"

  ingress {
    description = "HTTP from anywhere (DELIBERATE ISSUE: restrict this)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
