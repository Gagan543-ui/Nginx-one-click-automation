
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "owner" {
  description = "Owner tag"
  type        = string
  default     = "Shreyas"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "bastion_subnet_cidr" {
  description = "Public subnet for Bastion Host"
  type        = string
  default     = "10.0.1.0/24"
}

variable "nginx_subnet_cidr" {
  description = "Private subnet for NGINX EC2 instance"
  type        = string
  default     = "10.0.2.0/24"
}

variable "instance_type_bastion" {
  description = "Instance type for Bastion host"
  type        = string
  default     = "t3.micro"
}

variable "instance_type_nginx" {
  description = "Instance type for NGINX server"
  type        = string
  default     = "t3.micro"
}

variable "s3_bucket_name" {
  description = "Name of S3 bucket (must be globally unique)"
  type        = string
  default     = "abhinav-nginx-demo-bucket-18"
}

variable "key_name" {
  description = "Name of AWS key pair"
  type        = string
  default     = "nginx-demo-key"
}
