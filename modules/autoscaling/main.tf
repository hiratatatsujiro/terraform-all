
resource "aws_launch_template" "hirata_automation_launch_template" {
  name_prefix   = "hirata-automation-lt"
  image_id      = "ami-0a3c3a20c09d6f377"
  instance_type = "t3.micro"

  network_interfaces {
    device_index = 0
    description  = "Primary network interface"
    associate_public_ip_address = "true"
    security_groups           = [var.aws_security_group]
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 8  
      volume_type = "gp2"
      delete_on_termination = true
    }
  }
  
  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "hirata-automation-instance"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "hirata-automation-volume"
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    aws_region = var.aws_region  
  }))
}

resource "aws_autoscaling_group" "hirata_automation_autoscaling_group" {
  name = "hirata-automation-autoscaling-group" 
  desired_capacity     = 0
  max_size             = 0
  min_size             = 0
  vpc_zone_identifier  = [var.public_subnet_a, var.public_subnet_b]  # サブネットIDを指定

  launch_template {
    id      = aws_launch_template.hirata_automation_launch_template.id
    version = "$Latest"
  }

  health_check_type          = "ELB"
  health_check_grace_period  = 300
  force_delete               = true
  wait_for_capacity_timeout  = "0"
  target_group_arns          = [var.aws_lb_target_group]

  # タグ
  tag {
    key                 = "Name"
    value               = "hirata-automation-asg"
    propagate_at_launch = true
  }
}

# resource "aws_autoscaling_schedule" "scale_out" {
#   scheduled_action_name  = "scale-out"
#   autoscaling_group_name = aws_autoscaling_group.hirata_automation_autoscaling_group.name
#   desired_capacity       = 2
#   min_size               = 1
#   max_size               = 3
#   recurrence             = "0 22 * * SUN-THU" # UTC時間基準
# }

# resource "aws_autoscaling_schedule" "scale_in" {
#   scheduled_action_name  = "scale-in"
#   autoscaling_group_name = aws_autoscaling_group.hirata_automation_autoscaling_group.name
#   desired_capacity       = 1
#   min_size               = 1
#   max_size               = 3
#   recurrence             = "0 14 * * MON-FRI" # UTC時間基準
# }
