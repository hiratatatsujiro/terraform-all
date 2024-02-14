resource "aws_ecs_cluster" "hirata_automation_ecs_cluster" {
  name = "hirata-automation-ecs-cluster"
}

resource "aws_security_group" "hirata_automation_ecs_ec2_security_group" {
  name        = "hirata-automation-ecs-instance-ec2-sg"
  description = "hirata-automation-ecs-instance-ec2-sg"
  vpc_id      = var.vpc_id

  tags = {
    Name = "hirata-automation-ecs-instance-ec2-sg"
  }
}

resource "aws_security_group_rule" "hirata_automation_ecs_ec2_security_group_ingress_http_from_load_balancer" {
  type              = "ingress"
  from_port         = 32768
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.hirata_automation_ecs_ec2_security_group.id
  source_security_group_id = var.elb_security_group_id
  description       = "hirata_automation_alb-sg"
}

resource "aws_security_group_rule" "hirata_automation_ecs_ec2_security_group_egress_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"  # -1 はすべてのプロトコルを表します
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.hirata_automation_ecs_ec2_security_group.id
}

resource "aws_security_group_rule" "hirata_automation_ecs_ec2_security_group_ingress_mysql_to_rds" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  security_group_id = var.rds_security_group_id
  source_security_group_id = aws_security_group.hirata_automation_ecs_ec2_security_group.id
  description       = "hirata-automation-ecs-instance-ec2-sg"
}

resource "aws_iam_role" "hirata_automation_ecs_ec2_role" {
  name = "hirata-automation-ecs-ec2-role"

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
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]
}

resource "aws_iam_instance_profile" "example" {
  name = aws_iam_role.hirata_automation_ecs_ec2_role.name
  role = aws_iam_role.hirata_automation_ecs_ec2_role.name
}

resource "aws_launch_template" "hirata_automation_ecs_ec2_launch_template" {
  name = "hirata-automation-ecs-instance-lt"
  image_id      = "ami-08b9d579f842de8ef"
  instance_type = "t3.medium"
  instance_initiated_shutdown_behavior = "terminate"
  monitoring {
    enabled = false
  }
  metadata_options {
    http_tokens               = "required" # IMDSv2のみを許可
    http_put_response_hop_limit = 2 # Dockerコンテナからのメタデータへのアクセスを許可
    http_endpoint             = "enabled"
    instance_metadata_tags    = "disabled"
  }
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.hirata_automation_ecs_ec2_security_group.id]
    device_index                = 0
  }
  # block_device_mappings {
  #   device_name = "/dev/sda1"
  #   ebs {
  #     volume_size = 30  
  #     volume_type = "gp3"
  #     delete_on_termination = true
  #   }
  # }
  iam_instance_profile {
    name = aws_iam_instance_profile.example.name
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "hirata-automation-ecs-instance"
    }
  }
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    ecs_cluster_name = aws_ecs_cluster.hirata_automation_ecs_cluster.name 
  }))
}

resource "aws_autoscaling_group" "hirata_automaton_ecs_instance_asg" {
  name_prefix          = "hirata-automation-ecs-instance-asg"
  launch_template {
    id      = aws_launch_template.hirata_automation_ecs_ec2_launch_template.id
    version = "$Latest"
  }
  min_size             = 0
  max_size             = 0
  desired_capacity     = 0
  vpc_zone_identifier  = [var.public_subnet_a, var.public_subnet_b]
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "hirata-automation-ecs-instance"
    propagate_at_launch = true
  }
}

# Scheduled Actions for Auto Scaling Group
# resource "aws_autoscaling_schedule" "scale_out" {
#   scheduled_action_name  = "scale-out"
#   min_size               = var.asg_min_size
#   max_size               = var.asg_max_size
#   desired_capacity       = var.asg_desired_capacity
#   start_time             = "2023-01-01T07:00:00Z"
#   end_time               = "2023-12-31T23:00:00Z"
#   recurrence             = "0 22 * * SUN-THU"
#   autoscaling_group_name = aws_autoscaling_group.ecs_instance_asg.name
# }

# resource "aws_autoscaling_schedule" "scale_in" {
#   scheduled_action_name  = "scale-in"
#   min_size               = var.asg_min_size
#   max_size               = var.asg_max_size
#   desired_capacity       = var.asg_min_size
#   start_time             = "2023-01-01T23:00:00Z"
#   end_time               = "2023-12-31T07:00:00Z"
#   recurrence             = "0 14 * * MON-FRI"
#   autoscaling_group_name = aws_autoscaling_group.ecs_instance_asg.name
# }
