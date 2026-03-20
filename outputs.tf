# -----------------------------------------------------------------------------
# Outputs - Exposed values after terraform apply
# -----------------------------------------------------------------------------

# Unchanged — ALB DNS name remains the correct application entry point.
output "load_balancer_dns" {
  description = "Public URL to access the web application via the ALB"
  value       = aws_lb.app_lb.dns_name
}


# ASG name — useful for CLI queries and CI/CD pipeline references.
output "asg_name" {
  description = "Name of the Auto Scaling Group managing the web tier"
  value       = aws_autoscaling_group.web_asg.name
}

# Capacity summary — quick confirmation of scaling boundaries after apply.
output "asg_capacity" {
  description = "Min / desired / max capacity of the Auto Scaling Group"
  value       = "min=${var.asg_min_size}  desired=${var.asg_desired_capacity}  max=${var.asg_max_size}"
}

# Launch template ID — useful for verifying which version is active.
output "launch_template_id" {
  description = "ID of the Launch Template used by the ASG"
  value       = aws_launch_template.web_lt.id
}