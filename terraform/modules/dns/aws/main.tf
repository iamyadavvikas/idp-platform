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

resource "aws_route53_zone" "public" {
  count  = var.create_public_zone ? 1 : 0
  name   = var.domain_name

  tags = var.tags
}

resource "aws_route53_zone" "private" {
  count  = var.create_private_zone ? 1 : 0
  name   = var.domain_name
  vpc {
    vpc_id = var.vpc_id
  }

  tags = var.tags
}

resource "aws_route53_record" "wildcard" {
  count   = var.create_public_zone ? 1 : 0
  zone_id = aws_route53_zone.public[0].zone_id
  name    = "*.${var.domain_name}"
  type    = "A"
  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}