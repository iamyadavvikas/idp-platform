output "keyvault_id" {
  description = "ARN of the Secrets Manager"
  value       = aws_secretsmanager_secret.this.arn
}

output "keyvault_uri" {
  description = "Not applicable for AWS"
  value       = ""
}

output "identity_client_id" {
  description = "ARN of the External Secrets IAM role"
  value       = aws_iam_role.external_secrets.arn
}

output "identity_object_id" {
  description = "Not applicable for AWS"
  value       = ""
}