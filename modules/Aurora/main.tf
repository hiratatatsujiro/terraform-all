resource "aws_rds_cluster" "hirata_automation_db_cluster" {
  cluster_identifier      = "hirata-automation-rds-cluster"
  engine                  = var.engine
  engine_version          = "8.0.mysql_aurora.3.05.1"
  db_subnet_group_name    = aws_db_subnet_group.hirata_automation_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.hirata_automation_rds_sg.id]
  port                    = 3306
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.hirata_automation_db_cluster_parameter_group.name
  backup_retention_period = 3
  preferred_backup_window = "16:15-16:45"
  preferred_maintenance_window = "tue:16:45-tue:17:15"
  storage_encrypted       = true
  master_username = "root"
  master_password = random_password.password_root.result
}

resource "aws_rds_cluster_instance" "hirata_automation_db_instance_a" {
  identifier         = "hirata-automation-rds-instance-a"
  cluster_identifier = aws_rds_cluster.hirata_automation_db_cluster.id
  instance_class     = "db.t4g.medium"
  engine             = var.engine
  db_parameter_group_name = aws_db_parameter_group.hirata_automation_db_parameter_group.name
  preferred_maintenance_window = "tue:17:15-tue:17:45"
}

resource "aws_secretsmanager_secret" "secret_root" {
  name        = "SecretForRDS"
  description = "Secret for RDS (Master user (root))"
}

resource "aws_secretsmanager_secret" "secret_system" {
  name        = "SecretForRDS-hirata-automation"
  description = "Secret for RDS (User hirata-automation)"
}

resource "random_password" "password_root" {
  length           = 32
  special          = false
}

resource "aws_secretsmanager_secret_version" "version_root" {
  secret_id     = aws_secretsmanager_secret.secret_root.id
  secret_string = <<EOF
{
  "username": "root",
  "password": "${random_password.password_root.result}",
  "dbClusterIdentify": "${aws_rds_cluster.hirata_automation_db_cluster.cluster_identifier}",
  "engine": "${aws_rds_cluster.hirata_automation_db_cluster.engine}",
  "port": "${aws_rds_cluster.hirata_automation_db_cluster.port}",
  "host": "${aws_rds_cluster.hirata_automation_db_cluster.endpoint}"
}
EOF
}

resource "random_password" "password_system" {
  length           = 32
  special          = false
}

resource "aws_secretsmanager_secret_version" "version_system" {
  secret_id     = aws_secretsmanager_secret.secret_system.id
  secret_string = <<EOF
{
  "username": "hirata-automation",
  "password": "${random_password.password_system.result}",
  "dbClusterIdentify": "${aws_rds_cluster.hirata_automation_db_cluster.cluster_identifier}",
  "engine": "${aws_rds_cluster.hirata_automation_db_cluster.engine}",
  "port": "${aws_rds_cluster.hirata_automation_db_cluster.port}",
  "host": "${aws_rds_cluster.hirata_automation_db_cluster.endpoint}",
  "database": "hirata-automation"
}
EOF
}



resource "aws_security_group" "hirata_automation_rds_sg" {
  name        = "hirata-automation-rds-sg"
  description = "hirata-automation-rds-sg"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "egress_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"  # -1 はすべてのプロトコルを表します
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.hirata_automation_rds_sg.id
}

resource "aws_rds_cluster_parameter_group" "hirata_automation_db_cluster_parameter_group" {
  name        = "hirata-automation-rds-cluster-pg"
  family      = var.parameter_group_family
  description = "hirata-automation-rds-cluster-pg"
  parameter {
    name  = "require_secure_transport"
    value = "ON"
  }
}

resource "aws_db_parameter_group" "hirata_automation_db_parameter_group" {
  name        = "hirata-automation-rds-pg"
  family      = var.parameter_group_family
  description = "hirata-automation-rds-pg"
}

resource "aws_db_subnet_group" "hirata_automation_db_subnet_group" {
  name        = "hirata-automation-rds-subgrp"
  description = "DB Subnet Group for hirata-automation"
  subnet_ids  = var.subnet_ids
}
