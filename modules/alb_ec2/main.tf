resource "aws_iam_role" "hirata_automation_viaelb_ec2_role" {
  name = "hirata-automation-viaelb-ec2-role"

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
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    var.secrets_manager_get_secret_value
  ]
}

resource "aws_iam_instance_profile" "example" {
  name = aws_iam_role.hirata_automation_viaelb_ec2_role.name
  role = aws_iam_role.hirata_automation_viaelb_ec2_role.name
}

resource "aws_security_group" "hirata_automation_viaelb_ec2_sg" {
  name        = "hirata-automation-viaelb-ec2-sg"
  description = "hirata-automation-viaelb-ec2-sg"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.hirata_automation_viaelb_ec2_sg.id
  source_security_group_id = var.aws_security_group_elb
}

resource "aws_security_group_rule" "egress_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"  # -1 はすべてのプロトコルを表します
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.hirata_automation_viaelb_ec2_sg.id
}

resource "aws_security_group_rule" "ingress_mysql" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  security_group_id = var.aws_security_group_rds
  source_security_group_id = aws_security_group.hirata_automation_viaelb_ec2_sg.id
}

resource "aws_instance" "hirata_automation_viaelb_ec2" {
  ami           = "ami-0a3c3a20c09d6f377"
  instance_type = "t3.medium"
  iam_instance_profile = aws_iam_instance_profile.example.name
  subnet_id = var.subnet_id
  vpc_security_group_ids = [aws_security_group.hirata_automation_viaelb_ec2_sg.id]
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    aws_region = var.aws_region  
  }))
  # associate_public_ip_address = true
  tags = {
    Name = "hirata_automation_viaelb_ec2_instance"
  }
}

resource "aws_lb_target_group" "hirata_automation_lb_target_group" {
  name     = "hirata-automation-viaelb-ec2-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "instance"
  
  health_check {
    enabled = true
    path    = "/"
    protocol = "HTTP"
    matcher = "200,301" # 200番台と301を成功のステータスコードとして扱います
  }
}

resource "aws_lb_listener_rule" "example" {
  listener_arn = var.aws_lb_listener_https
  priority     = 21

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hirata_automation_lb_target_group.arn
  }

  condition {
    host_header {
      values = ["elb.hirata-automation.net"]
    }
  }
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_lb_target_group_attachment" "hirata_automation_viaelb_ec2_tg_attachment" {
  target_group_arn = aws_lb_target_group.hirata_automation_lb_target_group.arn
  target_id        = aws_instance.hirata_automation_viaelb_ec2.id
  port             = 80
}
