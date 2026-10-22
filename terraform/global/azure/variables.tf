variable "region" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    Project   = "idp-platform"
    ManagedBy = "terraform"
    Owner     = "platform-team"
  }
}