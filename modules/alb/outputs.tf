output "aws_security_group_elb" {
  value = aws_security_group.hirata_automation_alb_sg.id
}

output "aws_lb_listener_https" {
  value = aws_lb_listener.https.arn
}

output "alb_dns_name" {
  value = aws_lb.hirata_automation_alb.dns_name
}

output "aws_lb_listener_https_arn" {
  value = aws_lb_listener.https.arn
}

output "alb_id" {
  value = aws_lb.hirata_automation_alb.id
}