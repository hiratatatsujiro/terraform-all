resource "aws_iam_policy" "ssm_get_parameters" {
  name        = "hirata-automation-SSMGetParametersPolicy"
  description = "Policy for allowing SSM get parameters"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ],
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "secrets_manager_get_secret_value" {
  name        = "hirata-automation-SecretsManagerGetSecretValuePolicy"
  description = "Policy for allowing access to Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "secretsmanager:GetSecretValue",
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "ecs_execute_command" {
  name        = "hirata-automation-AmazonECSExecuteCommandPolicy"
  description = "Policy for ECS execute command"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "hirata-automation-mazonECSTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    aws_iam_policy.ssm_get_parameters.arn,
    aws_iam_policy.secrets_manager_get_secret_value.arn
  ]
}

resource "aws_iam_role" "ecs_instance" {
  name = "hirata-automation-AmazonSSMManagedECSInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "hirata-automation-AmazonRDSEnhancedMonitoringRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  ]
}
