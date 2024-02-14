variable "s3_bucket_static_contents_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "aws_lb_listener_https" {
  type = string
}

variable "secret_string" {
  type = string
}

variable "secret_system_arn" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "ecr_repository_app" {
  type = string
}

variable "ecr_repository_web" {
  type = string
}

variable "ecs_cluster_arn" {
  type = string
}