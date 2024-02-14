output "aws_ecr_repository_app" {
  value = aws_ecr_repository.hirata_automation_app.name
}

output "aws_ecr_repository_web" {
  value = aws_ecr_repository.hirata_automation_web.name
}