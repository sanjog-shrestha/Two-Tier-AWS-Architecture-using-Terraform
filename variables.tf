# -----------------------------------------------------------------------------
# Input Variables
# -----------------------------------------------------------------------------
# Variables allow parameterization without changing code. Pass values via
# -var, .tfvars file, or environment (TF_VAR_*).

# AWS region for all resources - determines physical location of infrastructure
variable "aws_region" {
  default = "eu-west-2"
}

# EC2 instance size - t3.micro is free-tier eligible
variable "instance_type" {
  default = "t3.micro"
}

# RDS master username - used to connect to MySQL database (required at apply)
variable "db_username" {
  description = "RDS master username - stored in Secrets Manager after first apply"
  sensitive   = true
}

# RDS master password - stored in state; use -var or TF_VAR_db_password (required)
variable "db_password" {
  description = "RDS master password - stored in Secrets Manager after first apply"
  sensitive   = true
}

variable "asg_min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  default     = 3
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  default     = 2
}
