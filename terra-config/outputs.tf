# ==============================================================================
# Terraform Outputs
# ==============================================================================
# Exposes critical infrastructure values after 'terraform apply' completes.
# These values are used to configure kubectl, link IRSA roles, and push Docker images.
# ==============================================================================

output "cluster_name" {
  description = "The name of the provisioned Amazon EKS Cluster"
  value       = aws_eks_cluster.eks_cluster.name
}

output "cluster_endpoint" {
  description = "The public/private HTTPS endpoint URL for the EKS control plane API server"
  value       = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane ENIs"
  value       = aws_security_group.eks_cluster.id
}

output "vpc_id" {
  description = "The ID of the dedicated EKS Virtual Private Cloud (VPC)"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "List of Public Subnet IDs (used by the NGINX Ingress Load Balancer)"
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "List of Private Subnet IDs (where worker nodes, pods, and databases execute)"
  value       = aws_subnet.private[*].id
}

output "oidc_provider_arn" {
  description = "IAM OIDC Provider ARN used to establish IRSA trust relationships"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "ecr_frontend_repository_url" {
  description = "Push/pull repository URI for the Frontend container image"
  value       = aws_ecrpublic_repository.frontend.repository_uri
}

output "ecr_backend_repository_url" {
  description = "Push/pull repository URI for the Backend container image"
  value       = aws_ecrpublic_repository.backend.repository_uri
}
