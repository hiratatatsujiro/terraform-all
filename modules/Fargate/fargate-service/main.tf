data "aws_caller_identity" "current" {}

resource "aws_security_group" "hirata_automation_fargate_security_group" {
  name        = "hirata-automation-fargate-sg"
  description = "hirata-automation-fargate-sg"
  vpc_id      = var.vpc_id

  tags = {
    Name = "hirata-automation-fargate-sg"
  }
}

resource "aws_security_group_rule" "hirata_automation_fargate_security_group_ingress_http_from_load_balancer" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.hirata_automation_fargate_security_group.id
  source_security_group_id = var.elb_security_group_id
  description       = "hirata_automation_alb-sg"
}

resource "aws_security_group_rule" "hirata_automation_fargate_security_group_egress_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"  # -1 はすべてのプロトコルを表します
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.hirata_automation_fargate_security_group.id
}

resource "aws_security_group_rule" "hirata_automation_fargate_security_group_ingress_mysql_to_rds" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  security_group_id = var.rds_security_group_id
  source_security_group_id = aws_security_group.hirata_automation_fargate_security_group.id
  description       = "hirata-automation-fargate-sg"
}

resource "aws_iam_role" "hirata_automation_fargate_task_role" {
  name = "hirata-automation-fargate-task-role"

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
    var.aws_ecs_execute_command_policy
  ]
}

resource "aws_iam_role_policy" "hirata_automation_fargate_s3_policy" {
  name   = "AmazonS3StaticContentsManipulateObjectPolicyFargate"
  role   = aws_iam_role.hirata_automation_fargate_task_role.id
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

resource "aws_lb_target_group" "hirata_automation_lb_fargate_target_group" {
  name     = "hirata-automation-fargate-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"
  
  health_check {
    enabled = true
    path    = "/users"
    protocol = "HTTP"
    matcher = "200,301"
  }
  tags = {
    "Name" = "hirata-automation-fargate-tg"
  }
}

resource "aws_lb_listener_rule" "example" {
  listener_arn = var.aws_lb_listener_https
  priority     = 23

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hirata_automation_lb_fargate_target_group.arn
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

resource "aws_cloudwatch_log_group" "hirata_automation_fargate_log_group" {
  name = "/ecs/hirata-automation-fargate-task"
}

resource "aws_ssm_parameter" "app_rails_env_fargate" {
  name  = "/hirata-automation/fargate/environment/app/rails-env"
  type  = "String"
  value = "development"
}

resource "aws_ecs_task_definition" "hirata_automation_fargate_task_defininition" {
  family                   = "hirata-automation-fargate-task"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = aws_iam_role.hirata_automation_fargate_task_role.arn
  network_mode             = "awsvpc"
  execution_role_arn       = var.ecs_task_execution_role_arn
  memory = 512
  cpu = 256
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
          awslogs-group         = aws_cloudwatch_log_group.hirata_automation_fargate_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "fargate"
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
          valueFrom = aws_ssm_parameter.app_rails_env_fargate.name
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
          protocol      = "tcp"
        }
      ]
      command          = ["/bin/bash", "-c", "envsubst '$$NGINX_BACKEND' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'"]
      environment = [
        {
          name  = "NGINX_BACKEND"
          value = "127.0.0.1"
        }
      ]
      volumesFrom       = []
      logConfiguration = {
        secretOptions = []
        logDriver = "awslogs"
        options   = {
          awslogs-group         = aws_cloudwatch_log_group.hirata_automation_fargate_log_group.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "fargate"
        }
      }
      linuxParameters = {
        initProcessEnabled = true
      }
    }
  ])
}

resource "aws_ecs_service" "hirata_automation_fargate_service" {
  name            = "hirata-automation-fargate-service"
  cluster         = var.fargate_cluster_arn
  task_definition = aws_ecs_task_definition.hirata_automation_fargate_task_defininition.arn
  desired_count   = 0
  scheduling_strategy = "REPLICA"
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_ecs_managed_tags = true
  enable_execute_command  = true
  health_check_grace_period_seconds = 300
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 0
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.hirata_automation_lb_fargate_target_group.arn
    container_name   = "web"
    container_port   = 80
  }
  deployment_controller {
    type = "ECS"
  }
  network_configuration {
    subnets = [var.public_subnet_a, var.public_subnet_b]
    security_groups = [aws_security_group.hirata_automation_fargate_security_group.id]
    assign_public_ip = true
  }
 }  






