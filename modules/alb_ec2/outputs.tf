output "aws_security_group" {
  value = aws_security_group.hirata_automation_viaelb_ec2_sg.id
}
output "aws_lb_target_group" {
  value = aws_lb_target_group.hirata_automation_lb_target_group.arn
}

output "iam_instance_profile_name" {
  value = aws_iam_role.hirata_automation_viaelb_ec2_role.name
}