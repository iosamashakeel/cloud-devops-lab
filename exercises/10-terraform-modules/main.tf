terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "./modules/network"

  name_prefix  = "lab-mod"
  vpc_cidr     = var.vpc_cidr
  subnet_cidr  = var.subnet_cidr
  availability_zone = var.availability_zone
}

# Same module, used twice. Only the name (and, in Task 4, the instance
# type) differs between the two servers.
module "web_a" {
  source = "./modules/web-server"

  name              = "web-a"
  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.subnet_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  allowed_ssh_cidr  = var.allowed_ssh_cidr
}

module "web_b" {
  source = "./modules/web-server"

  name              = "web-b"
  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.subnet_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  allowed_ssh_cidr  = var.allowed_ssh_cidr
}
