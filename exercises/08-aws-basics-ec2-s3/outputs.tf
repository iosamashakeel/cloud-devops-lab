output "instance_public_ip" {
  description = "Public IP of the EC2 instance (use for SSH)."
  value       = aws_instance.web.public_ip
}

output "website_url" {
  description = "URL of the page served by the instance."
  value       = "http://${aws_instance.web.public_ip}"
}

output "bucket_name" {
  description = "Name of the S3 bucket created by this exercise."
  value       = aws_s3_bucket.lab.bucket
}
