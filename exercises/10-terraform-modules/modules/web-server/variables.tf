variable "name" {
  description = "Name for the instance and security group (e.g. web-a)."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the security group belongs to."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet the instance runs in."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 key pair in the region."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH in (your own public IP /32). Never 0.0.0.0/0."
  type        = string
}
