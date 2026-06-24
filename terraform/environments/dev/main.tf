terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "idp-terraform-state"
    key            = "env/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "idp-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_id
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_id
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

module "vpc" {
  source = "../../modules/vpc"

  environment       = var.environment
  region            = var.region
  cidr_block        = var.vpc_cidr
  az_count          = var.az_count
  enable_nat_gateway = var.enable_nat_gateway
  tags              = var.tags
}

module "iam" {
  source = "../../modules/iam"

  environment = var.environment
  tags        = var.tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name        = "${var.environment}-${var.cluster_name}"
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = module.vpc.vpc_cidr
  subnet_ids          = module.vpc.private_subnet_ids
  cluster_role_arn    = module.iam.eks_cluster_role_arn
  node_role_arn       = module.iam.eks_node_group_role_arn
  kubernetes_version  = var.kubernetes_version
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  enable_spot_nodes   = var.enable_spot_nodes
  tags                = var.tags
}

module "route53" {
  source = "../../modules/route53"

  count       = var.create_dns_zone ? 1 : 0
  domain_name = var.domain_name
  alb_dns_name = var.alb_dns_name
  alb_zone_id  = var.alb_zone_id
  tags         = var.tags
}
