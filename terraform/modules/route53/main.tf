resource "aws_route53_zone" "public" {
  name = var.domain_name

  tags = merge(var.tags, {
    Name = "${var.domain_name}-public-zone"
  })
}

resource "aws_route53_record" "ns" {
  zone_id = aws_route53_zone.public.zone_id
  name    = aws_route53_zone.public.name
  type    = "NS"
  ttl     = 30

  records = aws_route53_zone.public.name_servers
}

resource "aws_route53_record" "wildcard" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "*.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "argocd" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "argocd.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "grafana" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "grafana.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
