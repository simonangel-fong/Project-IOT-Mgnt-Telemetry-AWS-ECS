# #################################
# Variable
# #################################
locals {
  svc_fastapi_log_group_name = "/ecs/task/${var.project}-${var.env}-fastapi"
  debug                      = var.env == "prod" ? false : true
}

# #################################
# IAM: ECS Task Execution Role
# #################################
# assume role
resource "aws_iam_role" "ecs_task_execution_role_api" {
  name               = "${var.project}-${var.env}-task-execution-role-api"
  assume_role_policy = data.aws_iam_policy_document.task_assume_policy.json

  tags = {
    Project = var.project
    Role    = "ecs-task-execution-role-api"
  }
}

# policy attachment: exec role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_api" {
  role       = aws_iam_role.ecs_task_execution_role_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# #################################
# IAM: ECS Task Role
# #################################
resource "aws_iam_role" "ecs_task_role_api" {
  name               = "${var.project}-${var.env}-task-role-api"
  assume_role_policy = data.aws_iam_policy_document.task_assume_policy.json

  # tags = {
  #   Project = var.project
  #   Role    = "ecs-task-role-api"
  # }
}

# ##############################
# Security Group
# ##############################
resource "aws_security_group" "sg_fastapi" {
  name        = "${var.project}-${var.env}-sg-api"
  description = "App security group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_lb.id] # limit source: sg_lb
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.env}-sg-api"
  }
}

# #################################
# CloudWatch: log group
# #################################
resource "aws_cloudwatch_log_group" "log_group_fastapi" {
  name              = local.svc_fastapi_log_group_name
  retention_in_days = 7
}

# #################################
# ECS: Task Definition
# #################################
resource "aws_ecs_task_definition" "ecs_task_fastapi" {
  family                   = "${var.project}-${var.env}-task-fastapi"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_task_execution_role_api.arn
  task_role_arn            = aws_iam_role.ecs_task_role_api.arn

  # method: json file
  # container_definitions = file("./container/fastapi.json")

  # method: template file
  container_definitions = templatefile("${path.module}/container/fastapi.json.tftpl", {
    image         = "${var.aws_ecr_fastapi}:${var.env}"
    awslogs_group = "${local.svc_fastapi_log_group_name}"
    region        = "${var.aws_region}"
    app_name      = "${var.project}"
    env           = "${var.env}"
    debug         = "${local.debug}"
    pgdb_host     = "${var.app_pgdb_host}"
    pgdb_db       = "${var.app_pgdb_db}"
    pgdb_user     = "${var.app_pgdb_user}"
    pgdb_pwd      = "${var.app_pgdb_pwd}"
    redis_host    = "${var.app_redis_host}"
  })

  tags = {
    Name = "${var.project}-${var.env}-task-api"
  }
}

# #################################
# ECS: Service
# #################################
resource "aws_ecs_service" "ecs_svc_fastapi" {
  name    = "${var.project}-${var.env}-service-fastapi"
  cluster = aws_ecs_cluster.ecs_cluster.id

  # task
  task_definition  = aws_ecs_task_definition.ecs_task_fastapi.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  # network
  network_configuration {
    security_groups  = [aws_security_group.sg_fastapi.id]
    subnets          = [for subnet in aws_subnet.public : subnet.id]
    assign_public_ip = true # enable public ip
  }

  # lb
  load_balancer {
    target_group_arn = aws_alb_target_group.lb_tg.id
    container_name   = "fastapi"
    container_port   = 8000
  }

  # service connect
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.ns_pgdb.arn

    service {
      discovery_name = "fastapi" # the name refered by other services refer
      port_name      = "fastapi" # must match port name in api.json

      client_alias {
        port     = 8000
        dns_name = "fastapi" # the name resolve by clients
      }
    }
  }

  tags = {
    Name = "${var.project}-${var.env}-service-api"
  }

  depends_on = [
    aws_cloudwatch_log_group.log_group_fastapi,
    aws_service_discovery_private_dns_namespace.ns_pgdb,
    aws_vpc_endpoint.ecr_api,
    aws_vpc_endpoint.ecr_dkr,
    aws_vpc_endpoint.s3,
  ]
}

# #################################
# Service: Scaling policy
# #################################
resource "aws_appautoscaling_target" "scaling_target_fastapi" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.ecs_svc_fastapi.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 20
}

# scaling policy: cpu
resource "aws_appautoscaling_policy" "scaling_cpu_fastapi" {
  name               = "${var.project}-scale-cpu-api"
  resource_id        = aws_appautoscaling_target.scaling_target_fastapi.resource_id
  scalable_dimension = aws_appautoscaling_target.scaling_target_fastapi.scalable_dimension
  service_namespace  = aws_appautoscaling_target.scaling_target_fastapi.service_namespace
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 30 # cpu%
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "scaling_memory_fastapi" {
  name               = "${var.project}-scale-memory-api"
  resource_id        = aws_appautoscaling_target.scaling_target_fastapi.resource_id
  scalable_dimension = aws_appautoscaling_target.scaling_target_fastapi.scalable_dimension
  service_namespace  = aws_appautoscaling_target.scaling_target_fastapi.service_namespace
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 40
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}
