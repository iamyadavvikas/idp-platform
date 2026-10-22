variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "domain_name" {
  description = "Domain name for DNS zone"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "create_public_zone" {
  description = "Create public DNS zone"
  type        = bool
  default     = true
}

variable "create_private_zone" {
  description = "Create private DNS zone"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID of the VPC for private DNS zone"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "Zone ID of the ALB"
  type        = string
  default     = ""
}