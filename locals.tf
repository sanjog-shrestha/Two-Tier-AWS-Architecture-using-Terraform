# -----------------------------------------------------------------------------
# Local Values - Common tags for resource grouping in AWS Console
# -----------------------------------------------------------------------------
# Locals are computed values used across the configuration. common_tags
# enables filtering all two-tier resources in AWS Console (Tag Editor, etc.).

locals {
  # Tags applied to all resources - filter by Project=two-tier in AWS Console
  common_tags = {
    Project = "two-tier"
  }
}
