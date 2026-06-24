variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the EKS cluster"
}

variable "cluster_role_arn" {
  type        = string
  description = "IAM role ARN for EKS cluster"
}

variable "node_role_arn" {
  type        = string
  description = "IAM role ARN for EKS node groups"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for secret encryption"
  default     = null
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
  default     = "1.29"
}

variable "vpc_cni_version" {
  type        = string
  default     = "v1.18.1-eksbuild.3"
}

variable "coredns_version" {
  type        = string
  default     = "v1.11.1-eksbuild.8"
}

variable "kube_proxy_version" {
  type        = string
  default     = "v1.29.3-eksbuild.5"
}

variable "ebs_csi_driver_version" {
  type        = string
  default     = "v1.34.0-eksbuild.1"
}

variable "endpoint_private_access" {
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  type        = list(string)
  default     = []
}

variable "cluster_log_types" {
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["m6i.large", "m5.large"]
}

variable "node_disk_size" {
  type        = number
  default     = 100
}

variable "node_desired_size" {
  type        = number
  default     = 3
}

variable "node_min_size" {
  type        = number
  default     = 3
}

variable "node_max_size" {
  type        = number
  default     = 10
}

variable "enable_spot_nodes" {
  type        = bool
  default     = false
}

variable "spot_instance_types" {
  type        = list(string)
  default     = ["m6i.large", "m5.large", "c5.large"]
}

variable "spot_desired_size" {
  type        = number
  default     = 0
}

variable "spot_min_size" {
  type        = number
  default     = 0
}

variable "spot_max_size" {
  type        = number
  default     = 20
}

variable "oidc_thumbprint" {
  type        = string
  default     = "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
}

variable "tags" {
  type        = map(string)
  default     = {}
}
