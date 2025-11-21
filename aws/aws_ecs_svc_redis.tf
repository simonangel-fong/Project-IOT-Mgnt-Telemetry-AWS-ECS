# #################################
# Variable
# #################################
locals {
  svc_redis_log_group_name = "/ecs/task/${var.project}-${var.env}-redis"
}

# #################################
# IAM: ECS Task Execution Role
# #################################
# assume role
resource "aws_iam_role" "ecs_task_execution_role_redis" {
  name               = "${var.project}-${var.env}-task-execution-role-redis"
  assume_role_policy = data.aws_iam_policy_document.task_assume_policy.json

  tags = {
    Role = "ecs-task-execution-role-redis"
  }
}

# policy attachment: exec role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_redis" {
  role       = aws_iam_role.ecs_task_execution_role_redis.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# #################################
# IAM: ECS Task Role
# #################################
resource "aws_iam_role" "ecs_task_role_redis" {
  name               = "${var.project}-${var.env}-task-role-redis"
  assume_role_policy = data.aws_iam_policy_document.task_assume_policy.json

  tags = {
    Role = "ecs-task-role-redis"
  }
}

# ##############################
# Security Group
# ##############################
resource "aws_security_group" "sg_redis" {
  name        = "${var.project}-${var.env}-sg-redis"
  description = "Redis security group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_fastapi.id] # limit source
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.env}-sg-redis"
  }
}

# #################################
# CloudWatch: log group
# #################################
resource "aws_cloudwatch_log_group" "log_group_redis" {
  name              = local.svc_redis_log_group_name
  retention_in_days = 7
}

# #################################
# ECS: Task Definition
# #################################
resource "aws_ecs_task_definition" "ecs_task_redis" {
  family                   = "${var.project}-${var.env}-task-redis"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_task_execution_role_redis.arn
  task_role_arn            = aws_iam_role.ecs_task_role_redis.arn

  # method: json file
  # container_definitions = file("./container/redis.json")

  # method: template file
  container_definitions = templatefile("${path.module}/container/redis.json.tftpl", {
    image         = "${var.aws_ecr_redis}:${var.env}"
    awslogs_group = "${local.svc_redis_log_group_name}"
    region        = "${var.aws_region}"
  })

  tags = {
    Name = "${var.project}-${var.env}-task-redis"
  }
}

# #################################
# ECS: Service
# #################################
resource "aws_ecs_service" "ecs_svc_redis" {
  name    = "${var.project}-${var.env}-service-redis"
  cluster = aws_ecs_cluster.ecs_cluster.id

  # task
  task_definition  = aws_ecs_task_definition.ecs_task_redis.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  # network
  network_configuration {
    security_groups  = [aws_security_group.sg_redis.id]
    subnets          = [for subnet in aws_subnet.private : subnet.id]
    assign_public_ip = false # disable public ip
  }

  # service connect
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.ns_pgdb.arn

    service {
      discovery_name = "redis" # the name refered by other services refer
      port_name      = "redis" # must match port name in api.json

      client_alias {
        port     = 6379
        dns_name = "redis" # the name resolve by clients
      }
    }
  }

  tags = {
    Name = "${var.project}-${var.env}-service-redis"
  }

  depends_on = [
    aws_cloudwatch_log_group.log_group_redis,
    aws_service_discovery_private_dns_namespace.ns_pgdb,
    aws_vpc_endpoint.ecr_api,
    aws_vpc_endpoint.ecr_dkr,
    aws_vpc_endpoint.s3,
  ]
}
