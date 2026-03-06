# -----------------------------------------------------------------------------
# Outputs - Exposed values after terraform apply
# -----------------------------------------------------------------------------
# Outputs are displayed after apply and can be queried with terraform output.
# Use these to get the ALB URL and SSH command.

# Load Balancer DNS - The public URL to access the application
# Purpose: Use this in a browser (http://<dns_name>) to reach the web server
output "load_balancer_dns" {
  value = aws_lb.app_lb.dns_name
}

# SSH Command - Pre-built command to connect to the web server
# Purpose: Copy-paste to SSH into EC2 (ensure two-tier-key.pem has chmod 400)
output "ssh_command" {
  value = "ssh -i two-tier-key.pem ubuntu@${aws_instance.web.public_ip}"
}
