# ==============================================================================
# AWS Secrets Manager & IAM Roles for Service Accounts (IRSA) Configuration
# ==============================================================================
# This file manages the root credentials for MongoDB in AWS Secrets Manager,
# defines an IAM policy to read the secret, and establishes an IAM Role with an
# OIDC Trust Policy enabling the Kubernetes ServiceAccount ('workshop-sa') to assume it.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. AWS Secrets Manager Secret
# ------------------------------------------------------------------------------
# Stores the production credentials for MongoDB securely outside the cluster.
resource "aws_secretsmanager_secret" "mongo_sec" {
  name                    = "workshop/mongo-sec"
  recovery_window_in_days = 0 # Set to 0 to permit immediate deletion/re-creation in dev/testing
  description             = "MongoDB credentials for the three-tier application stack"

  tags = {
    Environment = var.environment
    Application = "three-tier-app"
  }
}

# Initial secret value stored as a JSON object
resource "aws_secretsmanager_secret_version" "mongo_sec_val" {
  secret_id = aws_secretsmanager_secret.mongo_sec.id
  secret_string = jsonencode({
    username = "admin"
    password = "password123"
  })
}

# ------------------------------------------------------------------------------
# 2. IAM Policy to Read the MongoDB Secret
# ------------------------------------------------------------------------------
# Grants least-privilege read access strictly to the workshop/mongo-sec secret.
resource "aws_iam_policy" "secrets_manager_read" {
  name        = "workshop-secrets-manager-read"
  description = "Allows reading the MongoDB credentials secret from AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "${aws_secretsmanager_secret.mongo_sec.arn}*"
      }
    ]
  })
}

# Attach Policy to Node Group Role as a fallback mechanism for the CSI driver daemon
resource "aws_iam_role_policy_attachment" "nodegroup_secrets_read" {
  policy_arn = aws_iam_policy.secrets_manager_read.arn
  role       = aws_iam_role.nodegroup_role.name
}

# ------------------------------------------------------------------------------
# 3. IAM Role for Service Account (IRSA) for 'workshop-sa'
# ------------------------------------------------------------------------------
# Trust relationship bound to the EKS OIDC identity provider.
# ONLY the Kubernetes ServiceAccount named 'workshop-sa' inside the 'workshop' namespace
# is cryptographically authorized to assume this role via Web Identity token projection.
resource "aws_iam_role" "secrets_store_role" {
  name = "workshop-secrets-store-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # Binds role strictly to the workshop-sa service account in the workshop namespace
            "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:workshop:workshop-sa",
            "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Attach the Secrets Read policy to the IRSA role
resource "aws_iam_role_policy_attachment" "irsa_secrets_read" {
  policy_arn = aws_iam_policy.secrets_manager_read.arn
  role       = aws_iam_role.secrets_store_role.name
}

# ------------------------------------------------------------------------------
# 4. Outputs
# ------------------------------------------------------------------------------
output "secrets_store_role_arn" {
  description = "IAM Role ARN to annotate on the Kubernetes ServiceAccount (workshop-sa)"
  value       = aws_iam_role.secrets_store_role.arn
}

output "secrets_manager_secret_arn" {
  description = "ARN of the MongoDB secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.mongo_sec.arn
}
