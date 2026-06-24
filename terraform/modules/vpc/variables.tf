variable "environment" {
  type        = string
  description = "Environment name (dev, stage, prod)"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "cidr_block" {
  type        = string
  description = "VPC CIDR block"
}

variable "az_count" {
  type        = number
  description = "Number of availability zones to use"
  default     = 3
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Enable NAT Gateway for private subnets"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
