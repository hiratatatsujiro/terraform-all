variable "vpc_id" {
  type = string
}

variable "elb_security_group_id" {
  type = string
}

variable "rds_security_group_id" {
  type = string
}

variable "aws_ecs_execute_command_policy" {
  type = string
}

variable "aws_lb_listener_https" {
  type = string
}

variable "ecs_task_execution_role_arn" {
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

variable "fargate_cluster_arn" {
  type = string
}

variable "secret_system_arn" {
  type = string
}

variable "public_subnet_a" {
  type = string
}

variable "public_subnet_b" {
  type = string
}

variable "s3_bucket_static_contents_arn" {
  type = string
}

variable "secret_string" {
  type = string
}