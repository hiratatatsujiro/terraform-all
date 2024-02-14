variable "aws_security_group" {
  type    = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "public_subnet_a" {
  type    = string
}

variable "public_subnet_b" {
  type    = string
}

variable "aws_lb_target_group" {
  type = string
}

variable "iam_instance_profile_name" {
  type = string
}