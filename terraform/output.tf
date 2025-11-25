
output "vpc_id" {
  value = aws_vpc.nginx_vpc.id
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "nginx_private_ip" {
  value = aws_instance.nginx_server.private_ip
}

output "private_key_path" {
  description = "Local path of generated PEM key"
  value       = local_file.nginx_private_key.filename
}

output "s3_bucket_name" {
  value = aws_s3_bucket.nginx_bucket.id
}
