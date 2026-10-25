# ==============================================================================
# AWS IAM Roles and Policy Attachments for EKS
# ==============================================================================
# This file provisions the required IAM service roles for both the EKS Control Plane
# and the Managed Node Group, attaching the minimum required AWS managed policies.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. EKS Cluster Control Plane IAM Role
# ------------------------------------------------------------------------------
# Assumed by the Amazon EKS service to manage AWS infrastructure on your behalf
# (e.g., creating security groups, cross-account ENIs).
resource "aws_iam_role" "cluster_role" {
  name = "eks-role-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

# Attach AmazonEKSClusterPolicy: Grants permissions for cluster administration
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}

# ------------------------------------------------------------------------------
# 2. Worker Node Group IAM Role
# ------------------------------------------------------------------------------
# Assumed by EC2 worker instances to interact with the EKS cluster, manage VPC ENIs,
# pull container images from ECR, and attach EBS PersistentVolumes.
resource "aws_iam_role" "nodegroup_role" {
  name = "eks-node-group-example"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AmazonEKSWorkerNodePolicy: Allows nodes to connect to EKS clusters
resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodegroup_role.name
}

# Attach AmazonEKS_CNI_Policy: Allows the VPC CNI plugin to allocate secondary IPs to pods
resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodegroup_role.name
}

# Attach AmazonEC2ContainerRegistryReadOnly: Allows nodes to pull private/public container images from ECR
resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodegroup_role.name
}

# Attach AmazonEBSCSIDriverPolicy: Grants permissions to dynamically create, attach, detach,
# and expand AWS EBS gp3 volumes for MongoDB StatefulSets
resource "aws_iam_role_policy_attachment" "example-AmazonEBSCSIDriverPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.nodegroup_role.name
}