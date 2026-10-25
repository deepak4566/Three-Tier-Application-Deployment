# ==============================================================================
# Dedicated Multi-AZ Production VPC for Amazon EKS
# ==============================================================================
# This configuration creates a dedicated, highly available Virtual Private Cloud (VPC)
# across 2 Availability Zones, strictly isolating private workloads from public ingress.
#
# Network Architecture:
# - Public Subnets: Host the Internet-facing Ingress Load Balancer (NLB) & NAT Gateway.
# - Private Subnets: Host EKS Worker Nodes, Stateful MongoDB, and Backend/Frontend Pods.
#   Nodes have NO public IP addresses, eliminating direct attack surfaces from the Internet.
# - NAT Gateway: Allows private nodes to securely initiate outbound connections
#   (to pull container images from ECR, communicate with AWS APIs, etc.).
# ==============================================================================

# 1. Discover active Availability Zones in the current AWS region
data "aws_availability_zones" "available" {
  state = "available"
}

# ------------------------------------------------------------------------------
# 2. VPC Resource
# ------------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # Required by EKS for internal cluster DNS resolution
  enable_dns_support   = true # Required for AWS VPC Route 53 resolvers

  tags = {
    Name                                        = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared" # Identifies VPC to Kubernetes cluster
  }
}

# ------------------------------------------------------------------------------
# 3. Internet Gateway (IGW)
# ------------------------------------------------------------------------------
# Grants public subnets direct two-way access to the public Internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# ------------------------------------------------------------------------------
# 4. Public Subnets (Across 2 Availability Zones)
# ------------------------------------------------------------------------------
# Used exclusively for the Ingress Controller's Network Load Balancer (NLB)
# and the outbound NAT Gateway.
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1) # 10.0.1.0/24, 10.0.2.0/24
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # Automatically assign public IP to load balancers

  tags = {
    Name                                        = "${var.cluster_name}-public-${data.aws_availability_zones.available.names[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1" # Tells AWS Load Balancer Controller this subnet can host internet-facing ELBs
  }
}

# ------------------------------------------------------------------------------
# 5. Private Subnets (Across 2 Availability Zones)
# ------------------------------------------------------------------------------
# Worker nodes, pods, and databases live here without direct public Internet exposure.
resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 11) # 10.0.11.0/24, 10.0.12.0/24
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false # Do NOT assign public IPs to worker nodes

  tags = {
    Name                                        = "${var.cluster_name}-private-${data.aws_availability_zones.available.names[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1" # Tells AWS Load Balancer Controller this subnet is for internal/private services
  }
}

# ------------------------------------------------------------------------------
# 6. NAT Gateway & Static Elastic IP
# ------------------------------------------------------------------------------
# Provides secure one-way outbound Internet access for nodes in private subnets.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Placed inside the first public subnet

  tags = {
    Name = "${var.cluster_name}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ------------------------------------------------------------------------------
# 7. Route Tables & Associations
# ------------------------------------------------------------------------------
# Public Route Table: Routes 0.0.0.0/0 traffic directly out via Internet Gateway (IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

# Private Route Table: Routes 0.0.0.0/0 traffic out through the NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

# Bind public subnets to the public route table
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Bind private subnets to the private route table
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}