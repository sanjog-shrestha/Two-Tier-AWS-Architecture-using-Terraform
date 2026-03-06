# -----------------------------------------------------------------------------
# Security Groups - Network access rules for ALB, Web, and DB tiers
# -----------------------------------------------------------------------------
# Security groups act as virtual firewalls. Rules are stateful (reply traffic
# is automatically allowed). Each tier has its own SG with least-privilege rules.

# Web Security Group - Attached to EC2 web server
# Purpose: Allow HTTP from ALB only (no direct internet); SSH from anywhere for admin
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "web-sg"
  })

  # Ingress: Allow HTTP from ALB only - traffic must come through load balancer
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Ingress: Allow SSH from anywhere - for troubleshooting (restrict in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: Allow all outbound - needed for apt, MySQL connections, etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB Security Group - Attached to RDS MySQL instance
# Purpose: Allow MySQL (3306) only from web tier - database is not internet-accessible
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "db-sg"
  })

  # Ingress: Allow MySQL from web servers only - no direct DB access from internet
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }
  # Egress: Default allows all outbound (RDS needs this for replication, etc.)
}

# ALB Security Group - Attached to Application Load Balancer
# Purpose: Allow HTTP from internet; egress to forward traffic to targets
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "alb-sg"
  })

  # Ingress: Allow HTTP from anywhere - ALB is the public entry point
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress: Allow all outbound - ALB forwards to target group (web tier)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
