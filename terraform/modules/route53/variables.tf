variable "domain_name" {
  type        = string
  description = "Domain name for Route53 zone"
}

variable "alb_dns_name" {
  type        = string
  description = "ALB DNS name for alias records"
}

variable "alb_zone_id" {
  type        = string
  description = "ALB zone ID for alias records"
}

variable "tags" {
  type        = map(string)
  default     = {}
}
