#!/bin/bash
# Ref: https://docs.aws.amazon.com/ja_jp/AmazonECS/latest/developerguide/ecs-agent-config.html
echo ECS_CLUSTER=${ecs_cluster_name} >> /etc/ecs/ecs.config;
echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=true >> /etc/ecs/ecs.config;
echo ECS_LOG_MAX_ROLL_COUNT=168 >> /etc/ecs/ecs.config;