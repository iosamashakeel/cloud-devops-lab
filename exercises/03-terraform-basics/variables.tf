variable "container_name" {
  description = "Name of the Docker container Terraform manages."
  type        = string
  default     = "lab03-terraform"
}

variable "host_port" {
  description = "Host port mapped to the container's port 5000."
  type        = number
  default     = 5000
}
