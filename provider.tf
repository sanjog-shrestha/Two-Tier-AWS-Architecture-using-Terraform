# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
# Configures the AWS provider - required for all AWS resources. The region
# determines where resources are created (e.g., eu-west-2 = London).

provider "aws" {
  # Region where all resources will be provisioned (overridable via variable)
  region = var.aws_region
}
