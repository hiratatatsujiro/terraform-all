module "dynamodb" {
  source = "../../modules/DynamoDB"
}

module "vpc" {
  source = "../../modules/vpc"
}

module "Route53" {
  source = "../../modules/Route53"
}

module "certificate" {
  source = "../../modules/certificate"
}

module "iam_role" {
  source = "../../modules/IAMRole"
}

module "ec2" {
  source = "../../modules/ec2"

  vpc_id         = module.vpc.vpc_id
  subnet_id      = module.vpc.public_subnet_a
  hosted_zone_id = module.Route53.hosted_zone_id
  domain_name    = module.Route53.domain_name
}

module "alb" {
  source      = "../../modules/alb"
  vpc_id      = module.vpc.vpc_id
  subnet_id_a = module.vpc.public_subnet_a
  subnet_id_b = module.vpc.public_subnet_b
  certificate = module.certificate.certificate
  zone_id     = module.Route53.hosted_zone_id
}

module "alb_ec2" {
  source                           = "../../modules/alb_ec2"
  secrets_manager_get_secret_value = module.iam_role.secrets_manager_get_secret_value
  vpc_id                           = module.vpc.vpc_id
  aws_security_group_elb           = module.alb.aws_security_group_elb
  subnet_id                        = module.vpc.public_subnet_a
  aws_lb_listener_https            = module.alb.aws_lb_listener_https
  aws_security_group_rds           = module.aurora.aws_security_group_rds
}

module "aurora" {
  source                 = "../../modules/Aurora"
  engine                 = "aurora-mysql"
  vpc_id                 = module.vpc.vpc_id
  parameter_group_family = "aurora-mysql8.0"
  subnet_ids             = [module.vpc.public_subnet_a, module.vpc.public_subnet_b]
}

module "autoscaling" {
  source                    = "../../modules/autoscaling"
  aws_security_group        = module.alb_ec2.aws_security_group
  public_subnet_a           = module.vpc.public_subnet_a
  public_subnet_b           = module.vpc.public_subnet_b
  aws_lb_target_group       = module.alb_ec2.aws_lb_target_group
  iam_instance_profile_name = module.alb_ec2.iam_instance_profile_name
}

module "cloudfront" {
  source                      = "../../modules/CloudFront"
  acm_certificate_arn         = module.certificate.certificate
  elb_dns_name                = module.alb.alb_dns_name
  zone_id                     = module.Route53.hosted_zone_id
  elb_listner_https_arn       = module.alb.aws_lb_listener_https_arn
  elb_origin_id               = "ELB-hirata-automation-alb"
  s3_staticcontents_origin_id = "S3-hirata-automation-staticcontents"
  s3_website_origin_id        = "S3-Website-hirata-automation-redirections"
}

module "codepipline" {
  source = "../../modules/codepipline"
}

module "ecr" {
  source = "../../modules/ecr"
}

module "ecs_cluster" {
  source                = "../../modules/ecs/ecs-cluster"
  vpc_id                = module.vpc.vpc_id
  elb_security_group_id = module.alb.aws_security_group_elb
  rds_security_group_id = module.aurora.aws_security_group_rds
  public_subnet_a       = module.vpc.public_subnet_a
  public_subnet_b       = module.vpc.public_subnet_b
}

module "ecs_service" {
  source                = "../../modules/ecs/ecs-service"
  s3_bucket_static_contents_arn = module.cloudfront.s3_bucket_static_contents_arn
  aws_lb_listener_https = module.alb.aws_lb_listener_https_arn
  secret_string = module.cloudfront.secret_string
  vpc_id                = module.vpc.vpc_id
  secret_system_arn = module.aurora.aws_secretsmanager_version_system_arn
  ecr_repository_app = module.ecr.aws_ecr_repository_app
  ecr_repository_web = module.ecr.aws_ecr_repository_web
  ecs_cluster_arn = module.ecs_cluster.ecs_cluster_arn
}

module "fargate_cluster" {
  source = "../../modules/Fargate/fargate-cluster"
}

module "fargate_service" {
  source = "../../modules/Fargate/fargate-service"
  vpc_id                = module.vpc.vpc_id
  elb_security_group_id = module.alb.aws_security_group_elb
  rds_security_group_id = module.aurora.aws_security_group_rds
  aws_ecs_execute_command_policy = module.ecs_service.aws_iam_policy
  aws_lb_listener_https = module.alb.aws_lb_listener_https_arn
  ecs_task_execution_role_arn = module.ecs_service.ecs_task_execution_role
  ecr_repository_app = module.ecr.aws_ecr_repository_app
  ecr_repository_web = module.ecr.aws_ecr_repository_web
  fargate_cluster_arn = module.fargate_cluster.fargate_cluster_arn
  secret_system_arn = module.aurora.aws_secretsmanager_version_system_arn
  public_subnet_a       = module.vpc.public_subnet_a
  public_subnet_b       = module.vpc.public_subnet_b
  s3_bucket_static_contents_arn = module.cloudfront.s3_bucket_static_contents_arn
  secret_string = module.cloudfront.secret_string
}