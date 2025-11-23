# ##############################
# APP
# ##############################
variable "project" {
  type    = string
  default = "iot-mgnt-telemetry"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "app_pgdb_init_user" { type = string }
variable "app_pgdb_init_db" { type = string }
variable "app_pgdb_init_pwd" { type = string }
variable "app_pgdb_host" { type = string }
variable "app_pgdb_db" { type = string }
variable "app_pgdb_user" { type = string }
variable "app_pgdb_pwd" { type = string }
variable "app_redis_host" { type = string }

# ##############################
# AWS
# ##############################
variable "aws_region" { type = string }
data "aws_caller_identity" "current" {}

# # ##############################
# # Cloudflare
# # ##############################
variable "cloudflare_api_token" { type = string }
variable "cloudflare_zone_id" { type = string }

# ##############################
# AWS VPC
# ##############################
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "vpc_public_subnets" {
  type = map(object({
    subnet_name = string
    cidr_block  = string
    az_suffix   = string
  }))
  default = {
    public_subnet_1a = {
      subnet_name = "public_subnet_a"
      cidr_block  = "10.0.1.0/24"
      az_suffix   = "a"
    }
    public_subnet_1b = {
      subnet_name = "public_subnet_b"
      cidr_block  = "10.0.2.0/24"
      az_suffix   = "b"
    }
  }
}

variable "vpc_private_subnets" {
  type = map(object({
    subnet_name = string
    cidr_block  = string
    az_suffix   = string
  }))
  default = {
    public_subnet_1a = {
      subnet_name = "private_subnet_a"
      cidr_block  = "10.0.101.0/24"
      az_suffix   = "a"
    }
    public_subnet_1b = {
      subnet_name = "private_subnet_b"
      cidr_block  = "10.0.102.0/24"
      az_suffix   = "b"
    }
  }
}

# ##############################
# AWS ECR
# ##############################
locals {
  ecr_fastapi = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project}-fastapi:${var.env}"
  ecr_pgdb    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project}-pgdb:${var.env}"
  ecr_redis   = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project}-redis:${var.env}"
  ecr_device  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project}-device:${var.env}"
}

# ##############################
# AWS CF + CF
# ##############################
variable "dns_domain" {
  type    = string
  default = "arguswatcher.net"
}

locals {
  dns_name = var.env == "prod" ? "iot.${var.dns_domain}" : "iot-${var.env}.${var.dns_domain}"
  post_url = "https://${local.dns_name}/api/telemetry"
}

output "test" {
  value = local.post_url
}
