output "aws_iam_policy" {
  value = aws_iam_policy.hirata_automation_amazon_ecs_execute_command_policy.arn
}

output "ecs_task_execution_role" {
  value = aws_iam_role.hirata_automation_ecs_task_execution_role.arn
}