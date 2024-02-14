variable "vpc_id" {
  type = string
}

variable "elb_security_group_id" {
  type = string
}

variable "rds_security_group_id" {
  type = string
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