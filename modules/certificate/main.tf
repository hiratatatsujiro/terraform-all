resource "aws_acm_certificate" "certificate" {
  domain_name       = "hirata-automation.net"
  validation_method = "DNS"

  subject_alternative_names = ["*.hirata-automation.net"]

  tags = {
    Name = "hirata-automation-prod-certificate"
  }

  lifecycle {
    create_before_destroy = true
  }
}