resource "aws_iam_role" "hirata_automation_ec2_role" {
  name = "hirata_automation_ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
}

resource "aws_iam_role_policy" "hirata_automation_s3_policy" {
  name = "AmazonS3CfGetObjectPolicy"
  role = aws_iam_role.hirata_automation_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "s3:ListAllMyBuckets",
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "s3:ListBucket",
        Resource = "arn:aws:s3:::*"
      },
      {
        Effect = "Allow",
        Action = "s3:GetObject",
        Resource = "arn:aws:s3:::*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = aws_iam_role.hirata_automation_ec2_role.name
  role = aws_iam_role.hirata_automation_ec2_role.name
}

resource "aws_security_group" "hirata_automation_ec2_sg" {
  name        = "hirata_automation_ec2_sg"
  description = "hirata_automation_ec2_sg"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ingress_http_http" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.hirata_automation_ec2_sg.id
}

resource "aws_security_group_rule" "ingress_http_" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.hirata_automation_ec2_sg.id
}

resource "aws_security_group_rule" "egress_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"  # -1 はすべてのプロトコルを表します
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.hirata_automation_ec2_sg.id
}


resource "aws_instance" "hirata_automation_ec2_instance" {
  ami                    = "ami-0a3c3a20c09d6f377"
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.iam_instance_profile.name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.hirata_automation_ec2_sg.id]
  user_data              = base64encode(templatefile("${path.module}/user_data.sh", {
    aws_region = var.aws_region  
  }))
  tags = {
    Name = "hirata_automation_ec2_instance"
  }
}

resource "aws_eip" "eip" {
  instance = aws_instance.hirata_automation_ec2_instance.id
  tags = {
    Name = "hirata_automation_ec2"
  }
}

resource "aws_route53_record" "ipv4_record" {
  zone_id = var.hosted_zone_id
  name    = "ec2.${var.domain_name}"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.eip.public_ip]
}
