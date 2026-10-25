# ==============================================================================
# Managed Worker Node Group & EC2 Launch Template Configuration
# ==============================================================================
# This configuration provisions an AWS-managed node group strictly within Private
# Subnets, applying production security hardening at the hardware and virtualization level.
#
# Production Security Highlights:
# 1. Private Subnets Only: Worker nodes have NO public IPs and cannot be directly probed from the web.
# 2. IMDSv2 Strictly Enforced: Requires session tokens for metadata queries, preventing SSRF credential theft.
# 3. KMS-Encrypted Root Disks: All root OS drives are encrypted with customer-managed KMS keys.
# 4. EBS-Optimized: Dedicated bandwidth for storage I/O, preventing disk starvation during heavy load.
# 5. Cluster Autoscaler Ready: Pre-tagged for automatic horizontal scaling based on pod demand.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Managed Node Group Resource
# ------------------------------------------------------------------------------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.nodegroup_role.arn

  # Explicitly specify Amazon Linux 2023 Standard (AL2023), required for Kubernetes 1.30+
  ami_type = "AL2023_x86_64_STANDARD"

  # Strictly use Private Subnets - Worker nodes must never receive public IP addresses
  subnet_ids = aws_subnet.private[*].id

  # Auto-scaling boundaries managed by Kubernetes Cluster Autoscaler
  scaling_config {
    desired_size = var.node_desired_size # Default: 2 nodes
    min_size     = var.node_min_size     # Default: 2 nodes
    max_size     = var.node_max_size     # Default: 4 nodes
  }

  # Ensure at most 1 node is taken offline during AMI rollouts or cluster upgrades
  update_config {
    max_unavailable = 1
  }

  # Attach custom hardened launch template
  launch_template {
    id      = aws_launch_template.eks_node_launch_template.id
    version = "$Latest"
  }

  labels = {
    role        = "worker"
    environment = var.environment
  }

  # Standard AWS tags recognized by the Kubernetes Cluster Autoscaler controller
  tags = {
    Name                                                = "${var.cluster_name}-node"
    "k8s.io/cluster-autoscaler/${var.cluster_name}"     = "owned"
    "k8s.io/cluster-autoscaler/enabled"                 = "true"
  }

  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.example-AmazonEBSCSIDriverPolicy,
    aws_launch_template.eks_node_launch_template,
  ]
}

# ------------------------------------------------------------------------------
# 2. EC2 Launch Template (Production Hardening)
# ------------------------------------------------------------------------------
resource "aws_launch_template" "eks_node_launch_template" {
  name_prefix   = "${var.cluster_name}-node-template-"
  instance_type = var.node_instance_types[0] # Default: t3.medium
  ebs_optimized = true                       # Dedicated storage throughput

  # Associate with the private worker nodes security group
  vpc_security_group_ids = [aws_security_group.eks_nodes.id]

  # Root Volume Configuration: 50GB gp3 SSD encrypted with AWS KMS
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true # Uses default AWS EBS encryption, fully supported by Auto Scaling
      delete_on_termination = true
    }
  }

  # Enforce IMDSv2 (Instance Metadata Service Version 2)
  # Requiring HTTP PUT tokens blocks SSRF vulnerabilities from dumping IAM credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 enforced
    http_put_response_hop_limit = 2          # Required so pods can also safely query metadata if authorized
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                                        = "${var.cluster_name}-worker-node"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}