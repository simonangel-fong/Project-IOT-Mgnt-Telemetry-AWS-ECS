# #################################
# Variable
# #################################
locals {
  svc_device_log_group_name = "/ecs/task/${var.project}-${var.env}-device"
}

# #################################
# IAM: ECS Task Execution Role
# #################################
# assume role
resource "aws_iam_role" "ecs_task_execution_role_device" {
  name               = "${var.project}-${var.env}-task-execution-role-device"
  assume_role_policy = data.aws_iam_policy_document.task_assume_policy.json

  # tags = {
  #   Project = var.project
  #   Role    = "ecs-task-execution-role-device"
  # }
}

# policy attachment: exec role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_device" {
  role       = aws_iam_role.ecs_task_execution_role_device.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# #################################
# IAM: ECS Task Role
# #################################
resource "aws_iam_role" "ecs_task_role_device" {
  name               = "${var.project}-${var.env}-task-role-device"
  assume_role_policy = data.aws_iam_policy_document.task_assume_policy.json

  # tags = {
  #   Project = var.project
  #   Role    = "ecs-task-role-device"
  # }
}

# ##############################
# Security Group
# ##############################
resource "aws_security_group" "sg_device" {
  name        = "${var.project}-${var.env}-sg-device"
  description = "App security group"
  vpc_id      = aws_vpc.vpc.id

  # Egress to vpc only
  egress {
    description = "Allow vpc egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "${var.project}-${var.env}-sg-device"
  }
}

# #################################
# CloudWatch: log group
# #################################
resource "aws_cloudwatch_log_group" "log_group_device" {
  name              = local.svc_device_log_group_name
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch_logs.arn

  tags = {
    Name = "${var.project}-${var.env}-log-group-device"
  }
}

# #################################
# ECS: Task Definition
# #################################
resource "aws_ecs_task_definition" "ecs_task_device" {
  family                   = "${var.project}-${var.env}-task-device"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role_device.arn
  task_role_arn            = aws_iam_role.ecs_task_role_device.arn

  # method: json file
  # container_definitions = file("./container/device.json")

  # method: template file
  container_definitions = templatefile("${path.module}/container/device.json.tftpl", {
    image         = local.ecr_device
    awslogs_group = local.svc_device_log_group_name
    interval      = 1
    remote        = local.dns_name
    region        = var.aws_region
    # app_name      = var.project
  })

  tags = {
    Name = "${var.project}-${var.env}-task-device"
  }
}

# # #################################
# # ECS: Service
# # #################################
# resource "aws_ecs_service" "ecs_svc_device" {
#   name    = "${var.project}-${var.env}-service-device"
#   cluster = aws_ecs_cluster.ecs_cluster.id

#   # task
#   task_definition  = aws_ecs_task_definition.ecs_task_device.arn
#   desired_count    = 1
#   launch_type      = "FARGATE"
#   platform_version = "LATEST"

#   # network
#   network_configuration {
#     security_groups  = [aws_security_group.sg_device.id]
#     subnets          = [for subnet in aws_subnet.public : subnet.id]
#     assign_public_ip = true # enable public ip
#   }

#   deployment_minimum_healthy_percent = 50
#   deployment_maximum_percent         = 200

#   lifecycle {
#     ignore_changes = [desired_count]
#   }

#   tags = {
#     Name = "${var.project}-${var.env}-service-device"
#   }

#   depends_on = [
#     aws_cloudwatch_log_group.log_group_device,
#   ]
# }
