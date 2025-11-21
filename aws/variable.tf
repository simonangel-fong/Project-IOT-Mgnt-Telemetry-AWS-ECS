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
variable "aws_ecr_fastapi" { type = string }
variable "aws_ecr_pgdb" { type = string }
variable "aws_ecr_redis" { type = string }

# ##############################
# AWS CF + CF
# ##############################
variable "dns_domain" {
  type    = string
  default = "arguswatcher.net"
}

locals {
  dns_name = var.env == "prod" ? "iot.${var.dns_domain}" : "iot-${var.env}.${var.dns_domain}"
}
