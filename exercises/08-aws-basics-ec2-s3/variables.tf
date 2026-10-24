variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-central-1"
}

variable "instance_type" {
  description = "EC2 instance type. t3.micro is in the AWS free tier for new accounts."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in the region (see README Task 0)."
  type        = string
  default     = "lab-key"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the instance. Use your own public IP as /32, never 0.0.0.0/0."
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr must be a valid CIDR block, e.g. 203.0.113.10/32."
  }
}

variable "bucket_name" {
  description = "S3 bucket name. Leave empty to generate a unique name automatically. Bucket names are globally unique and must be lowercase, with no spaces."
  type        = string
  default     = ""
}
