# -----------------------------------------------------------------------------
# EC2 Instance - Ubuntu 22.04 LTS with Nginx installed via user data
# -----------------------------------------------------------------------------
# The web tier runs a single EC2 instance. User data installs Nginx and
# mysql-client at boot. Traffic reaches it via the ALB (not direct).

# Web Server EC2 Instance - Hosts the application tier
resource "aws_instance" "web" {
  # Ubuntu 22.04 LTS AMI for eu-west-2 (verify AMI ID for your region)
  ami           = "ami-018ff7ece22bf96db"
  instance_type = var.instance_type

  # Placed in public subnet for internet access (apt, etc.)
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # SSH key for ubuntu user access
  key_name = aws_key_pair.generated_key.key_name

  # User data runs at first boot - installs Nginx and mysql-client
  # Purpose: Bootstrap the instance without a separate configuration tool
  user_data = <<-EOF
                #!/bin/bash

                # Force IPV4 for apt (avoids IPv6 issues in some VPCs)
                echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

                # Wait for apt lock to release (cloud-init may hold it)
                while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
                    echo "Waiting for apt lock..."
                    sleep 5
                done

                apt-get update -y
                apt-get install -y nginx mysql-client
                
                systemctl start nginx
                systemctl enable nginx

                echo "Hello from Terraform Web Server on Ubuntu" > /var/www/html/index.html
                EOF

  tags = merge(local.common_tags, {
    Name = "WebServer"
  })

  # Public IP for SSH and outbound internet (user data needs apt)
  associate_public_ip_address = true
}
