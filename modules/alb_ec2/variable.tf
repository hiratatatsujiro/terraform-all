variable "secrets_manager_get_secret_value" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "aws_security_group_elb" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "subnet_id" {
  type = string
}

variable "aws_lb_listener_https" {
  type = string
}

variable "aws_security_group_rds" {
  type = string
}