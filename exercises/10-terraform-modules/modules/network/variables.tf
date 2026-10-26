variable "name_prefix" {
  description = "Prefix for the Name tags on all network resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for the public subnet."
  type        = string
}
