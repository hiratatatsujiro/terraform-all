output "hosted_zone_id" {
  value = aws_route53_zone.hosted_zone.id
}

output "domain_name" {
   value = aws_route53_record.caa_record.name
}