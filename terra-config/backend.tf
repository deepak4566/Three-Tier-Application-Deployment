# ==============================================================================
# Terraform Remote State Backend Configuration
# ==============================================================================
# This block configures Terraform to store its state file remotely in an Amazon S3
# bucket instead of locally on disk. 
#
# Key Benefits in Production:
# 1. Team Collaboration: Shared single source of truth for infrastructure state.
# 2. Security: State is encrypted at rest (AES256) inside the S3 bucket.
# 3. State Locking: (Optional via DynamoDB) Prevents concurrent runs from colliding
#    or corrupting the state file.
# ==============================================================================

terraform {
  backend "s3" {
    # Name of the S3 bucket created for storing Terraform state
    # NOTE: S3 bucket names are globally unique; update this if using a different bucket.
    bucket         = "jeeban-terra-state-bucket"

    # The path/key inside the S3 bucket where the state file will be saved
    key            = "eks/terraform.tfstate"

    # The AWS region where the state bucket is located
    region         = "us-east-1"

    # Enforce server-side encryption of the state file at rest
    encrypt        = true

    # Optional: Enable distributed state locking using a DynamoDB table
    # dynamodb_table = "terraform-lock-table"
  }
}
