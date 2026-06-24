variable "environment" {
  type    = string
  default = "prod"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "idp"
}

variable "vpc_cidr" {
  type    = string
  default = "10.2.0.0/16"
}

variable "az_count" {
  type    = number
  default = 3
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m6i.large", "m5.large", "c6i.large"]
}

variable "node_desired_size" {
  type    = number
  default = 5
}

variable "node_min_size" {
  type    = number
  default = 3
}

variable "node_max_size" {
  type    = number
  default = 15
}

variable "enable_spot_nodes" {
  type    = bool
  default = false
}

variable "create_dns_zone" {
  type    = bool
  default = true
}

variable "domain_name" {
  type    = string
  default = "idp.example.com"
}

variable "alb_dns_name" {
  type    = string
  default = ""
}

variable "alb_zone_id" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {
    Environment = "prod"
    ManagedBy   = "terraform"
    Project     = "idp"
  }
}
