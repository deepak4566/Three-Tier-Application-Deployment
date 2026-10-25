# ==============================================================================
# Amazon Elastic Container Registry (ECR Public)
# ==============================================================================
# Provisions public container registries for storing and sharing Docker images
# for both the Frontend and Backend application tiers.
# ==============================================================================

# Public ECR repository for the React frontend application container image
resource "aws_ecrpublic_repository" "frontend" {
  repository_name = "three-tier-frontend"

  tags = {
    Tier = "frontend"
  }
}

# Public ECR repository for the Node.js Express backend application container image
resource "aws_ecrpublic_repository" "backend" {
  repository_name = "three-tier-backend"

  tags = {
    Tier = "backend"
  }
}