resource "aws_ecs_cluster" "hirata_automation_ecs_cluster" {
  name = "hirata-automation-fargate-cluster"
}

resource "aws_ecs_cluster_capacity_providers" "hirata_automation_capacity_provider" {
  cluster_name = aws_ecs_cluster.hirata_automation_ecs_cluster.name
  capacity_providers = ["FARGATE"]
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

