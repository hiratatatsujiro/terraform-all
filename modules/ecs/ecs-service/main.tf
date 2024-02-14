data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "hirata_automation_amazon_ecs_execute_command_policy" {
  name        = "AmazonECSExecuteCommandPolicy"
  description = "Policy for Amazon ECS Execute Command"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "hirata_automation_ecs_task_role" {
  name = "hirata-automation-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })

  managed_policy_arns = [
    aws_iam_policy.hirata_automation_amazon_ecs_execute_command_policy.arn
  ]
}

resource "aws_iam_role_policy" "hirata_automation_ecs_s3_policy" {
  name   = "AmazonS3StaticContentsManipulateObjectPolicy"
  role   = aws_iam_role.hirata_automation_ecs_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = "var.s3_bucket_static_contents_arn"
      },
    ],
    Statement = [
      {
        Action = [
          "s3:*Object",
        ]
        Effect   = "Allow"
        Resource = "${var.s3_bucket_static_contents_arn}/*"
      },
    ]
  })
}

resource "aws_lb_target_group" "hirata_automation_lb_ecs_target_group" {
  name     = "hirata-automation-ecs-ec2-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "instance"
  
  health_check {
    enabled = true
    path    = "/"
    protocol = "HTTP"
    matcher = "200,301"
  }
}

resource "aws_lb_listener_rule" "example" {
  listener_arn = var.aws_lb_listener_https
  priority     = 22

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hirata_automation_lb_ecs_target_group.arn
  }

  condition {
    http_header {
      http_header_name = "x-via-cloudfront"
      values           = [var.secret_string]
    }
  }
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_cloudwatch_log_group" "hirata_automation_ecs_log_group" {
  name = "/ecs/hirata-automation-ecs-task"
}

resource "aws_ssm_parameter" "app_rails_env" {
  name  = "/hirata-automation/ecs/environment/app/rails-env"
  type  = "String"
  value = "development"
}

resource "aws_iam_role" "hirata_automation_ecs_task_execution_role" {
  name = "hirata-automation-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.hirata_automation_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
  
resource "aws_iam_policy" "AmazonSSMGetParametersPolicy" {
  name        = "AmazonSSMGetParametersPolicy"
  path        = "/"
  description = "Policy for allowing access to SSM parameters"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
        ],
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "SecretsManagerGetSecretValuePolicy" {
  name        = "SecretsManagerGetSecretValuePolicy-automation"
  path        = "/"
  description = "Policy for allowing access to Secrets Manager secret values"

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


resource "aws_iam_role_policy_attachment" "AmazonSSMGetParametersPolicyAttachment" {
  role       = aws_iam_role.hirata_automation_ecs_task_execution_role.name
  policy_arn = aws_iam_policy.AmazonSSMGetParametersPolicy.arn
}

resource "aws_iam_role_policy_attachment" "SecretsManagerGetSecretValuePolicyAttachment" {
  role       = aws_iam_role.hirata_automation_ecs_task_execution_role.name
  policy_arn = aws_iam_policy.SecretsManagerGetSecretValuePolicy.arn
}

resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRolePolicyAttachment" {
  role       = aws_iam_role.hirata_automation_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_ecs_task_definition" "hirata_automation_ecs_task_defininition" {
  family                   = "hirata-automation-ecs-task"
  requires_compatibilities = ["EC2"]
  task_role_arn            = aws_iam_role.hirata_automation_ecs_task_role.arn
  network_mode             = "bridge"
  execution_role_arn       = aws_iam_role.hirata_automation_ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name             = "app"
      mountPoints       = []
      image            = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository_app}:latest"
      cpu              = 0
      memoryReservation = 80
      essential        = true
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://127.0.0.1:3000/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 180
      }
      portMappings     = []
      logConfiguration = {
        secretOptions = []
        logDriver = "awslogs"
        options   = {
          awslogs-group         = aws_cloudwatch_log_group.hirata_automation_ecs_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      volumesFrom       = []
      secrets = [
        {
          name      = "MYSQL_DATABASE"
          valueFrom = "${var.secret_system_arn}:database::"
        },
        {
          name      = "MYSQL_HOST"
          valueFrom = "${var.secret_system_arn}:host::"
        },
         {
          name      = "MYSQL_PASSWORD"
          valueFrom = "${var.secret_system_arn}:password::"
        },
        {
          name      = "MYSQL_USER"
          valueFrom = "${var.secret_system_arn}:username::"
        },
        {
          name      = "RAILS_ENV"
          valueFrom = aws_ssm_parameter.app_rails_env.name
        },
      ]
      environment = [
        {
          name  = "RAILS_CONFIG_HOSTS"
          value = ".hirata-automation.net"
        }
      ]
    },
    {
      name             = "web"
      mountPoints       = []
      image            = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository_web}:latest"
      links = ["app"]
      cpu              = 0
      memoryReservation = 16
      essential        = true
      dependsOn = [
                    {
                      condition     = "HEALTHY"
                      containerName = "app"
                    },
                  ]
      portMappings     = [
        {
          name          = "web-80-tcp"
          containerPort = 80
          hostPort      = 0
          protocol      = "tcp"
        }
      ]
      command          = ["/bin/bash", "-c", "envsubst '$$NGINX_BACKEND' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
      environment = [
        {
          name  = "NGINX_BACKEND"
          value = "app"
        }
      ]
      volumesFrom       = []
      logConfiguration = {
        secretOptions = []
        logDriver = "awslogs"
        options   = {
          awslogs-group         = aws_cloudwatch_log_group.hirata_automation_ecs_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      linuxParameters = {
        initProcessEnabled = true
      }
    }
  ])
}

resource "aws_ecs_service" "hirata_automation_ecs_service" {
  name            = "hirata-automation-ecs-service"
  cluster         = var.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.hirata_automation_ecs_task_defininition.arn
  desired_count   = 2
  launch_type     = "EC2"
  scheduling_strategy = "REPLICA"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_ecs_managed_tags = true
  enable_execute_command  = true
  health_check_grace_period_seconds = 300
  load_balancer {
    target_group_arn = aws_lb_target_group.hirata_automation_lb_ecs_target_group.arn
    container_name   = "web"
    container_port   = 80
  }
  deployment_controller {
    type = "ECS"
  }
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }
  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
 }  






