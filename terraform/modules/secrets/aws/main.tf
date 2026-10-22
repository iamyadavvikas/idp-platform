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

locals {
  secrets_name = var.secrets_manager_name != "" ? var.secrets_manager_name : "${var.environment}-secrets"
}

resource "aws_secretsmanager_secret" "this" {
  name = local.secrets_name

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "demo_db_password" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    password = "changeme-${var.environment}"
  })
}

resource "aws_secretsmanager_secret_version" "demo_api_key" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    api_key = "changeme-${var.environment}"
  })
}

resource "aws_iam_role" "external_secrets" {
  name = "${var.environment}-external-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.oidc_provider_url}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:external-secrets:external-secrets"
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "external_secrets" {
  name = "${var.environment}-external-secrets-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = aws_secretsmanager_secret.this.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}