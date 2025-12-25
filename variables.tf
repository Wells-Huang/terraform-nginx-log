# variables.tf

variable "aws_region" {
  description = "The AWS region to deploy resources."
  type        = string
  default     = "ap-northeast-1" # 東京區域
}

variable "project_name" {
  description = "A name for the project to prefix resources."
  type        = string
  default     = "nginx-log-poc"
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket for logs. Must be globally unique."
  type        = string
  default     = "my-nginx-log-bucket-20251219" # 務必更換為自己的唯一名稱
}

variable "ec2_instance_type" {
  description = "The instance type for the EC2 server."
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "The name of the EC2 key pair for SSH access. (Optional)"
  type        = string
  default     = null # 建議建立並填寫，以便登入主機排查問題
}

