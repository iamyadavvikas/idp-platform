output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "eks_cluster_role_name" {
  value = aws_iam_role.eks_cluster.name
}

output "eks_node_group_role_arn" {
  value = aws_iam_role.eks_node_group.arn
}

output "eks_node_group_role_name" {
  value = aws_iam_role.eks_node_group.name
}

output "ebs_csi_driver_role_arn" {
  value = aws_iam_role.ebs_csi_driver.arn
}

output "external_dns_policy_arn" {
  value = aws_iam_policy.external_dns.arn
}

output "cert_manager_policy_arn" {
  value = aws_iam_policy.cert_manager.arn
}
