resource "aws_route53_zone" "hosted_zone" {
  name = "hirata-automation.net"

  tags = {
    Name = "hirata-automation-hostedzone"
  }
}

resource "aws_route53_record" "caa_record" {
  zone_id = aws_route53_zone.hosted_zone.zone_id
  name    = "hirata-automation.net"
  type    = "CAA"
  ttl     = "3600"
  records = ["0 issue \"amazon.com\""]
}