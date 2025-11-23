# ##############################
# Log group
# ##############################

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/vpc/flow-logs/${var.project}-${var.env}"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.cloudwatch_logs.arn

  tags = {
    Name = "${var.project}-${var.env}-logs-vpc-flow"
  }
}

# ##############################
# VPC
# ##############################
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-${var.env}-vpc"
  }
}

# ##############################
# Internet Gateway
# ##############################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.project}-${var.env}-igw"
  }
}

# ##############################
# Route Table
# ##############################
# rt: default, private
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id

  tags = {
    Name = "${var.project}-${var.env}-default-rt-private"
  }
}

# rt public
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}-${var.env}-rt-public"
  }
}

# ##############################
# Subnet
# ##############################

# private subnet
resource "aws_subnet" "private" {
  for_each = var.vpc_private_subnets

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = "${var.aws_region}${each.value.az_suffix}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project}-${var.env}-${each.value.subnet_name}"
  }
}

# public subnet
resource "aws_subnet" "public" {
  for_each = var.vpc_public_subnets

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = "${var.aws_region}${each.value.az_suffix}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-${each.value.subnet_name}"
  }
}

# ##############################
# Route Table Associations
# ##############################
resource "aws_route_table_association" "default" {
  for_each       = var.vpc_private_subnets
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_default_route_table.default.id
}

resource "aws_route_table_association" "public" {
  for_each       = var.vpc_public_subnets
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}



# #################################
# VPC Endpoints:
# #################################
# VPC endpoint for ecr api
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [for subnet in aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.sg_vpc_ep.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-vpcep-ecr-api"
  }
}

# VPC endpoint for ecr dkr
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [for subnet in aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.sg_vpc_ep.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-${var.env}-vpc-endpoint-ecr-dkr"
  }
}

# VPC endpoint for image via S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  # default rt in private subnet
  route_table_ids = [
    aws_default_route_table.default.id,
  ]

  tags = {
    Name = "${var.project}-${var.env}-vpc-endpoint-s3"
  }
}

# VPC Endpoint for CloudWatch Logs
resource "aws_vpc_endpoint" "logs" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type = "Interface"

  subnet_ids          = [for subnet in aws_subnet.private : subnet.id]
  security_group_ids  = [aws_security_group.sg_vpc_ep.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-${var.env}-vpc-endpoint-logs"
  }
}

# #################################
# SG: Interface Endpoints
# #################################
resource "aws_security_group" "sg_vpc_ep" {
  name        = "${var.project}-${var.env}-sg-vpc-endpoint"
  description = "Security group for VPC interface endpoints (ECR API/DKR)"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Allow HTTPS ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [
      aws_security_group.sg_pgdb.id,    # allow db task
      aws_security_group.sg_fastapi.id, # allow api task
      aws_security_group.sg_redis.id,   # allow api task
      aws_security_group.sg_device.id,  # allow device task
    ]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.env}-sg-vpc-endpoint"
  }
}
