# ==============================================================================
# Terraform & AWS Provider Configuration
# ==============================================================================
# This file specifies the required Terraform core version and provider plugins,
# as well as the default configuration and resource tagging for all AWS resources.
# ==============================================================================

terraform {
  # Minimum required Terraform CLI version for syntax and feature support
  required_version = ">= 1.3.0"

  required_providers {
    # HashiCorp AWS provider for creating VPC, EKS, IAM, EC2, KMS, etc.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # TLS provider for extracting EKS OIDC thumbprints for IRSA authentication
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# ------------------------------------------------------------------------------
# AWS Provider Block
# ------------------------------------------------------------------------------
provider "aws" {
  # The AWS region targeted for deploying infrastructure (e.g., us-east-1)
  region = var.aws_region

  # Default tags automatically applied to every taggable AWS resource created by Terraform.
  # This ensures consistent cost tracking, governance, and asset ownership.
  default_tags {
    tags = {
      Project     = "Three-Tier-App"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}