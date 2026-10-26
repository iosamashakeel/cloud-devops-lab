variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the public subnet."
  type        = string
  default     = "eu-central-1a"
}

variable "instance_type" {
  description = "EC2 instance type for both web servers."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in the region."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH in (your own public IP /32). Never 0.0.0.0/0."
  type        = string
}
