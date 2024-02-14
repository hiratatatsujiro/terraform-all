data "aws_caller_identity" "current" {}

# S3: Bucket (Access Logs)
resource "aws_s3_bucket" "hirata_automation_alb_access_logs" {
  bucket = "hirata-automation-alb-accesslogs-${data.aws_caller_identity.current.account_id}"
  tags = {
    Name = "hirata_automation_alb_accesslogs_${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "hirata_automation_alb_access_logs_sse" {
  bucket = aws_s3_bucket.hirata_automation_alb_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "hirata_automation_alb_access_logs_lifecycle" {
  bucket = aws_s3_bucket.hirata_automation_alb_access_logs.id

  rule {
    id     = "log"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "hirata_automation_alb_logs_policy" {
  bucket = aws_s3_bucket.hirata_automation_alb_access_logs.id
  policy = data.aws_iam_policy_document.hirata_automation_alb_logs_policy_document.json
}

data "aws_iam_policy_document" "hirata_automation_alb_logs_policy_document" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      # ここにロードバランサーのリージョンに対応する AWSアカウントIDを記載する
      identifiers = ["127311923021"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.hirata_automation_alb_access_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
  }
}

# EC2(VPC): Security Group
resource "aws_security_group" "hirata_automation_alb_sg" {
  name        = "hirata_automation_alb_sg"
  description = "hirata_automation_alb_sg"
  vpc_id      = var.vpc_id # VPC IDを指定

  tags = {
    Name  = "hirata_automation_alb_sg"
  }
}

# EC2(VPC): Security Group Inbound Rule (HTTP and HTTPS)
resource "aws_security_group_rule" "http_ingress_http" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.hirata_automation_alb_sg.id
}

resource "aws_security_group_rule" "https_ingress_https" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.hirata_automation_alb_sg.id
}

resource "aws_security_group_rule" "egress_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"  # -1 はすべてのプロトコルを表します
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.hirata_automation_alb_sg.id
}

# ELB: Load Balancer (ALB)
resource "aws_lb" "hirata_automation_alb" {
  name               = "hirata-automation-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.hirata_automation_alb_sg.id]
  subnets            = [var.subnet_id_a, var.subnet_id_b]

  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.hirata_automation_alb_access_logs.bucket
    enabled = true
  }

  tags = {
    Name        = "hirata_automation_alb"
  }
}

# ELB: Listeners (HTTP and HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.hirata_automation_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.hirata_automation_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = var.certificate

  default_action {
    type = "fixed-response"
    fixed_response {
      status_code = "403"
      content_type = "text/plain"
      message_body = "Forbiddenなり"
    }
  }
}

# Route 53: Record Set (IPv4)
resource "aws_route53_record" "ipv4" {
  zone_id = var.zone_id
  name    = "elb.hirata-automation.net"
  type    = "A"

  alias {
    name                   = aws_lb.hirata_automation_alb.dns_name
    zone_id                = aws_lb.hirata_automation_alb.zone_id
    evaluate_target_health = true
  }
}
