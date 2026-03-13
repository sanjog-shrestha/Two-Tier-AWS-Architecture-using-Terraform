# -----------------------------------------------------------------------------
# VPC - Custom network 10.0.0.0/16 with DNS support enabled
# -----------------------------------------------------------------------------
# The VPC is the isolated network container. All subnets, instances, and
# load balancers live inside it. DNS support enables Route 53 Resolver.

# Main VPC - Isolated network boundary for the two-tier architecture
resource "aws_vpc" "main" {
  # CIDR defines the IP range for the entire VPC (65,536 addresses)
  cidr_block = "10.0.0.0/16"

  # Required for private DNS resolution (e.g., RDS endpoint from EC2)
  enable_dns_support   = true
  enable_dns_hostnames = true

  # Tags for identification and cost allocation
  tags = merge(local.common_tags, {
    Name = "two-tier-vpc"
  })
}

# -----------------------------------------------------------------------------
# Public Subnets (x2) - 10.0.1.0/24 and 10.0.2.0/24 across eu-west-2a / eu-west-2b
# -----------------------------------------------------------------------------
# Public subnets have a route to the Internet Gateway. Used for ALB and EC2
# instances that need direct internet access.

# Public subnet in AZ-A - Hosts ALB and web server
resource "aws_subnet" "public_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  # Spread across AZs for high availability
  availability_zone = "eu-west-2a"
  # EC2 instances get a public IP automatically (needed for internet access)
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "public-subnet-1"
  })
}

# Public subnet in AZ-B - Second subnet for ALB multi-AZ deployment
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "public-subnet-2"
  })
}

# -----------------------------------------------------------------------------
# Private DB Subnets (x2) - 10.0.3.0/24 and 10.0.4.0/24, isolated from internet
# -----------------------------------------------------------------------------
# Private subnets have no route to the internet. RDS lives here for security -
# only reachable from within the VPC (e.g., from the web tier).

# Private DB subnet in AZ-A - RDS primary can be placed here
resource "aws_subnet" "private_db_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-2a"
  # No map_public_ip - instances stay private

  tags = merge(local.common_tags, {
    Name = "private-db-subnet-1"
  })
}

# Private DB subnet in AZ-B - Required for RDS Multi-AZ (2 subnets in 2 AZs)
resource "aws_subnet" "private_db_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-2b"

  tags = merge(local.common_tags, {
    Name = "private-db-subnet-2"
  })
}
