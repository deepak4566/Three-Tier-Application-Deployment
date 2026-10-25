# ==============================================================================
# Amazon EKS Cluster & Managed Add-ons Configuration
# ==============================================================================
# This file provisions the Amazon EKS control plane, configures security logging,
# enables KMS envelope encryption for Kubernetes Secrets, sets up the IAM OIDC
# identity provider for IRSA, and installs core Kubernetes managed add-ons.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. CloudWatch Log Group for EKS Control Plane Audit Logs
# ------------------------------------------------------------------------------
# Captures audit logs, authenticator requests, API server calls, and scheduler events.
# Essential for security compliance, incident response, and troubleshooting.
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30 # Retain logs for 30 days to optimize cost while maintaining compliance

  tags = {
    Name = "${var.cluster_name}-cloudwatch-logs"
  }
}

# ------------------------------------------------------------------------------
# 2. Production EKS Cluster Control Plane
# ------------------------------------------------------------------------------
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster_role.arn
  version  = var.kubernetes_version # Active Standard Support version (1.31)

  # Stream all 5 critical control plane log streams to CloudWatch
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    # Control Plane ENIs are placed across both public and private subnets
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true # Nodes communicate with API server securely within the VPC
    endpoint_public_access  = true # Allows management via kubectl from external authorized networks
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  # Enforce Envelope Encryption for Kubernetes Secrets at rest inside etcd
  # Protects against physical or snapshot compromise of the underlying etcd storage.
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.eks_cluster,
  ]

  tags = {
    Name = var.cluster_name
  }
}

# ------------------------------------------------------------------------------
# 3. OIDC Identity Provider for IAM Roles for Service Accounts (IRSA)
# ------------------------------------------------------------------------------
# Allows Kubernetes ServiceAccounts (e.g. workshop-sa) to directly assume AWS IAM
# roles without needing long-lived AWS access keys or node-wide permissions.
data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.cluster_name}-irsa-provider"
  }
}

# ------------------------------------------------------------------------------
# 4. Core Managed EKS Add-ons
# ------------------------------------------------------------------------------
# VPC CNI: Manages native AWS VPC IP allocation for Kubernetes pods
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "vpc-cni"
}

# Kube-proxy: Manages network routing for Kubernetes Services (iptables/IPVS)
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "kube-proxy"
}

# CoreDNS: Internal cluster DNS resolution daemon for services and pods
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "coredns"

  depends_on = [
    aws_eks_node_group.main # CoreDNS requires running worker nodes to schedule pods
  ]
}

# AWS EBS CSI Driver: Dynamically provisions and attaches EBS gp3 volumes for StatefulSets
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = "aws-ebs-csi-driver"

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.example-AmazonEBSCSIDriverPolicy
  ]
}