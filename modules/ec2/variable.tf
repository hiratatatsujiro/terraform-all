variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  type = string
}
 
variable "subnet_id" {
  type = string
}
  

variable "hosted_zone_id" {
  type = string
}

variable "domain_name" {
  type = string
}
