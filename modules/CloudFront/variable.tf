variable "acm_certificate_arn" {
  type = string
}

variable "elb_dns_name" {
  type = string
}

variable "zone_id" {
  type = string
}

variable "elb_listner_https_arn" {
  type = string
}

variable "elb_origin_id" {
  type = string
}

variable "s3_staticcontents_origin_id" {
  type = string
}

variable "s3_website_origin_id" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}