# ==============================================================================
# Security Groups for Amazon EKS Control Plane & Worker Nodes
# ==============================================================================
# This configuration defines strict network access controls adhering to the
# principle of least privilege.
#
# Rules Breakdown:
# 1. Cluster SG: Allows secure HTTPS (443) communication from worker nodes to API server.
# 2. Nodes SG: Allows intra-node communication (pod network overlay), kubelet checks
#    from the control plane (port 10250), and inbound traffic from Public Subnets (Ingress NLB).
# 3. No open SSH (port 22) to the world.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. EKS Cluster Control Plane Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for the EKS control plane ENIs"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic from the control plane
  egress {
    description = "Allow all outbound traffic from control plane"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

# ------------------------------------------------------------------------------
# 2. Worker Nodes Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "eks_nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  description = "Security group for all worker nodes in the cluster"
  vpc_id      = aws_vpc.main.id

  # Ingress Rule 1: Allow intra-node communication
  # Pods running across different EC2 nodes must communicate with each other
  # over the AWS VPC CNI overlay network.
  ingress {
    description = "Allow node-to-node communication for pod networking"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Ingress Rule 2: Control plane to worker nodes on port 443
  ingress {
    description     = "Allow control plane to communicate with pods running webhooks"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # Ingress Rule 3: Control plane to kubelet on port 10250
  # Enables 'kubectl logs' and 'kubectl exec' to reach the kubelet daemon on nodes.
  ingress {
    description     = "Allow control plane to communicate with kubelet"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # Ingress Rule 4: Traffic from Public Subnets for Ingress Controllers
  # When external requests hit the NGINX Ingress Load Balancer in the public subnet,
  # the traffic is forwarded to NodePort/IP targets on worker nodes in private subnets.
  ingress {
    description = "Allow traffic from public subnets for NGINX Ingress Controller"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = aws_subnet.public[*].cidr_block
  }

  # Egress: Allow worker nodes full outbound access via the NAT Gateway
  egress {
    description = "Allow all outbound traffic from worker nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                        = "${var.cluster_name}-nodes-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# ------------------------------------------------------------------------------
# 3. Allow Worker Nodes to reach the Cluster API Server on port 443
# ------------------------------------------------------------------------------
resource "aws_security_group_rule" "cluster_ingress_nodes" {
  description              = "Allow worker nodes to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
}
