terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, length(var.subnet_ids))
  
  default_node_pools = {
    general = {
      name                = "general"
      instance_types      = ["t3.medium"]
      min_size            = 1
      max_size            = 5
      desired_size        = 2
      enable_spot         = false
      capacity_type       = "ON_DEMAND"
      node_labels         = {}
      node_taints         = []
    }
    spot = {
      name                = "spot"
      instance_types      = ["t3.medium", "t3.large"]
      min_size            = 0
      max_size            = 10
      desired_size        = 2
      enable_spot         = true
      capacity_type       = "SPOT"
      node_labels         = {}
      node_taints         = []
    }
  }
  
  merged_node_pools = merge(local.default_node_pools, var.node_pools)
}

resource "aws_eks_cluster" "this" {
  name                      = var.cluster_name
  role_arn                  = var.cluster_role_arn
  version                   = var.kubernetes_version
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.environment == "dev"
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}

resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

resource "aws_security_group_rule" "cluster_inbound_https" {
  description       = "Allow inbound HTTPS from within VPC"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = [var.vpc_cidr]
  type              = "ingress"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "aws-ebs-csi-driver"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

dynamic "node_pool" {
  for_each = var.merged_node_pools
  content {
    resource "aws_eks_node_group" "this" {
      cluster_name    = aws_eks_cluster.this.name
      node_group_name = "${var.cluster_name}-${node_pool.value.name}"
      node_role_arn   = var.node_role_arn
      subnet_ids      = var.subnet_ids

      instance_types = node_pool.value.instance_types
      disk_size      = 50

      capacity_type = node_pool.value.capacity_type

      scaling_config {
        desired_size = node_pool.value.desired_size
        min_size     = node_pool.value.min_size
        max_size     = node_pool.value.max_size
      }

      update_config {
        max_unavailable = 1
      }

      labels = node_pool.value.node_labels

      taints = [
        for taint in node_pool.value.node_taints : {
          key    = split("=", taint)[0]
          value  = length(split("=", taint)) > 1 ? split("=", taint)[1] : ""
          effect = contains(taint, "NoSchedule") ? "NO_SCHEDULE" : "PREFER_NO_SCHEDULE"
        }
      ]

      tags = merge(var.tags, {
        Name = "${var.cluster_name}-${node_pool.value.name}-ng"
      })
    }
  }
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}