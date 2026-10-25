# ==============================================================================
# Terraform Input Variables
# ==============================================================================
# This file defines all configurable input variables for the AWS EKS deployment.
# You can override these defaults via a terraform.tfvars file or CLI flags (-var).
# ==============================================================================

variable "aws_region" {
  description = "The target AWS region where all infrastructure components will be provisioned."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "The name of the Amazon EKS cluster and prefix for related IAM/network resources."
  type        = string
  default     = "Three-tier-cloud"
}

variable "kubernetes_version" {
  description = "The target Kubernetes minor version for the EKS control plane (1.31 is in active Standard Support)."
  type        = string
  default     = "1.31"
}

variable "environment" {
  description = "Environment identifier tag (e.g., production, staging, development)."
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "The primary IPv4 CIDR block allocated to the dedicated EKS Virtual Private Cloud (VPC)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group (t3.medium offers 2 vCPU, 4GB RAM, and ample ENI IP capacity)."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Initial target number of active worker nodes in the managed node group."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes that the cluster autoscaler can scale down to."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes that the cluster autoscaler can scale up to."
  type        = number
  default     = 4
}
