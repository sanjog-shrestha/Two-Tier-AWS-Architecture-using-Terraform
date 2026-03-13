# -----------------------------------------------------------------------------
# Database - RDS MySQL 8.0, private instance (db.t3.micro, 20GB)
# -----------------------------------------------------------------------------
# RDS runs in private subnets. Only the web tier (via db_sg) can connect.
# DB subnet group spans 2 AZs for RDS placement requirements.

# RDS MySQL Instance - Managed database for the application
resource "aws_db_instance" "database" {
  identifier = "two-tier-db"

  # Storage and engine configuration
  allocated_storage = 20
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"

  # Credentials - pass via -var or TF_VAR_* (never commit)
  username = jsondecode(data.aws_secretsmanager_secret_version.db_credentials.secret_string)["username"]
  password = jsondecode(data.aws_secretsmanager_secret_version.db_credentials.secret_string)["password"]

  # Network - RDS must be in a DB subnet group (private subnets)
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  # Security: No public IP - only reachable from within VPC (web tier)
  publicly_accessible = false

  # Skip final snapshot on destroy (set to false for production backups)
  skip_final_snapshot = true

  tags = merge(local.common_tags, {
    Name = "two-tier-db"
  })
}

# DB Subnet Group - Defines which subnets RDS can use
# Purpose: RDS requires 2+ subnets in different AZs for Multi-AZ and placement
resource "aws_db_subnet_group" "db_subnet_group" {
  name = "db-subnet-group"

  # Private subnets in 2 AZs - satisfies RDS AZ coverage requirement
  subnet_ids = [
    aws_subnet.private_db_1.id,
    aws_subnet.private_db_2.id
  ]

  tags = merge(local.common_tags, {
    Name = "DB subnet group"
  })
}
