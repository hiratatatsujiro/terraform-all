output "aws_security_group_rds" {
  value = aws_security_group.hirata_automation_rds_sg.id
}

output "aws_secretsmanager_version_system_arn" {
  value = aws_secretsmanager_secret_version.version_system.arn
}
