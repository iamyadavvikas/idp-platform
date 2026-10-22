output "service_account_client_ids" {
  description = "Map of service account names to role ARNs"
  value       = { for k, v in aws_iam_role.service_accounts : k => v.arn }
}