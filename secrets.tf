# -----------------------------------------------------------------------------
# Secrets - AWS Secrets Manager for RDS credentials
# -----------------------------------------------------------------------------
# This file manages storage of the RDS username/password in AWS Secrets Manager.
# The secret is written once from Terraform input variables, then read back
# by the database configuration to avoid hardcoding credentials.

# Secret Container - Logical holder for DB credentials in Secrets Manager
# Purpose: Central, encrypted storage for username/password JSON blob
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "two-tier/rds/credentials"
  description = "RDS MySql Credentials for two-tier architecture"

  tags = merge(local.common_tags, {
    Name = "two-tier-db-credentials"
  })
}

# Secret Version - Writes username and password as JSON into the secret
# Purpose: Initial population of credentials; can be rotated manually later
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}

# Data Source - Reads the latest secret value for use in database.tf
# Purpose: Allows RDS resource to consume credentials without exposing them
data "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id  = aws_secretsmanager_secret.db_credentials.id
  depends_on = [aws_secretsmanager_secret_version.db_credentials]
}