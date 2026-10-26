output "web_a_url" {
  description = "Public URL of the first web server."
  value       = "http://${module.web_a.public_ip}"
}

output "web_b_url" {
  description = "Public URL of the second web server."
  value       = "http://${module.web_b.public_ip}"
}

output "vpc_id" {
  description = "ID of the VPC created by the network module."
  value       = module.network.vpc_id
}
