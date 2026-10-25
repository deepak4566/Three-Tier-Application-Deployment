# ==============================================================================
# AWS KMS Customer Managed Key (CMK) for EKS Data Encryption
# ==============================================================================
# In production environments, sensitive data must be encrypted using customer-managed
# cryptographic keys with automatic rotation enabled.
#
# Use Cases:
# 1. EKS Secrets Envelope Encryption: Encrypts Kubernetes Secrets at rest inside etcd.
# 2. Worker Node Disk Encryption: Encrypts EBS root storage volumes (/dev/xvda) on nodes.
# 3. Persistent Volumes: Used by AWS EBS CSI driver to encrypt gp3 volumes for MongoDB.
# ==============================================================================

resource "aws_kms_key" "eks" {
  description             = "Customer Managed KMS Key for ${var.cluster_name} EKS cluster secrets and EBS encryption"
  deletion_window_in_days = 7 # Grace period before permanent key destruction if destroyed

  # Automatically rotate the cryptographic key material once every 365 days
  # without invalidating previously encrypted data. (Security Best Practice)
  enable_key_rotation     = true

  tags = {
    Name = "${var.cluster_name}-kms-key"
  }
}

# Human-readable alias for referencing the KMS key easily
resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-key"
  target_key_id = aws_kms_key.eks.key_id
}
