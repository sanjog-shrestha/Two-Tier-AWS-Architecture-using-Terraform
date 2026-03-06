# -----------------------------------------------------------------------------
# RSA Key Pair - Auto-generated 4096-bit SSH key (two-tier-key.pem)
# -----------------------------------------------------------------------------
# Generates an SSH key pair for EC2 access. The private key is saved locally;
# the public key is registered with AWS for EC2 instances.

# TLS Private Key - Generates the key pair (used by Terraform TLS provider)
# Purpose: Creates a cryptographically secure key without manual ssh-keygen
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# AWS Key Pair - Registers the public key with AWS
# Purpose: EC2 instances use this to allow SSH login; key_name is referenced by aws_instance
resource "aws_key_pair" "generated_key" {
  key_name   = "two-tier-key"
  public_key = tls_private_key.key.public_key_openssh

  tags = merge(local.common_tags, {
    Name = "two-tier-key"
  })
}

# Local File - Saves the private key to disk
# Purpose: You need two-tier-key.pem to SSH into the EC2 instance (chmod 400 recommended)
resource "local_file" "private_key" {
  filename = "two-tier-key.pem"
  content  = tls_private_key.key.private_key_pem
}
