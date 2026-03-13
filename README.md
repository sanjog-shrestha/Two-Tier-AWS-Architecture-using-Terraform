# 🏗️ Two-Tier AWS Architecture with Terraform

## 📌 Overview

This project demonstrates how to deploy a **production-style two-tier web application** on **Amazon Web Services (AWS)** using **HashiCorp Terraform** Infrastructure as Code (IaC).

Terraform provisions and configures all required AWS resources automatically — including a custom VPC, public/private subnets, an Application Load Balancer, an EC2 web server, and a private RDS MySQL database — enabling repeatable and version-controlled infrastructure deployments.

The infrastructure includes:
- Custom VPC with public and private subnets across 2 Availability Zones
- Application Load Balancer (ALB)
- EC2 web server (Ubuntu + Nginx)
- RDS MySQL database (private, not publicly accessible)
- Security groups with least-privilege access
- Auto-generated RSA SSH key pair
- AWS Secrets Manager for encrypted RDS credential management

This project highlights cloud networking, multi-tier architecture design, infrastructure security, and DevOps deployment practices.

---

## 🏗️ Architecture

```
Internet
    ↓ (port 80)
Application Load Balancer (ALB)
    ↓ (port 80)
┌─────────────────────────────────────┐
│           VPC (10.0.0.0/16)         │
│                                     │
│  Public Subnet 1    Public Subnet 2 │
│  (eu-west-2a)       (eu-west-2b)    │
│       ↓                             │
│   EC2 WebServer (Nginx)             │
│       ↓ (port 3306)                 │
│  Private Subnet 1  Private Subnet 2 │
│  (eu-west-2a)      (eu-west-2b)     │
│       └──── RDS MySQL ─────┘        │
└─────────────────────────────────────┘
```

> 📸 **Architecture Screenshot:**
<img width="1024" height="1536" alt="image" src="https://github.com/user-attachments/assets/5f8d3e4f-253b-4ea6-b719-876fcc959eb3" />

---

## ☁️ AWS Deployment

### Provisioned Resources

| Resource | Description |
|---|---|
| VPC | Custom network `10.0.0.0/16` with DNS support enabled |
| Public Subnets (×2) | `10.0.1.0/24` and `10.0.2.0/24` across `eu-west-2a` / `eu-west-2b` |
| Private DB Subnets (×2) | `10.0.3.0/24` and `10.0.4.0/24` — isolated from internet |
| Internet Gateway | Routes public traffic into the VPC |
| Route Table | Directs `0.0.0.0/0` traffic through the Internet Gateway |
| ALB Security Group | Allows inbound HTTP (port 80) from internet |
| Web Security Group | Allows HTTP from ALB only; SSH from anywhere |
| DB Security Group | Allows MySQL (port 3306) from web server only |
| Application Load Balancer | Public-facing ALB across both public subnets |
| Target Group + Listener | Forwards HTTP traffic to EC2 on port 80 |
| EC2 Instance | Ubuntu 22.04 LTS with Nginx installed via user data |
| RDS MySQL 8.0 | Private database instance (`db.t3.micro`, 20GB) |
| DB Subnet Group | Multi-AZ subnet group for RDS |
| RSA Key Pair | Auto-generated 4096-bit SSH key (`two-tier-key.pem`) |
| Secrets Manager | Encrypted RDS credentials (`two-tier/rds/credentials`) |

> 📸 **AWS Console Screenshot:**
<img width="1678" height="666" alt="image" src="https://github.com/user-attachments/assets/d30ff93c-577c-4310-972a-82b67126b10c" />


---

## 📂 Repository Structure

```
terraform-aws-two-tier/
├── provider.tf        # AWS provider and region configuration
├── variables.tf       # Input variable definitions
├── vpc.tf             # VPC, subnets, route tables
├── security.tf        # Security groups (ALB, web, DB)
├── keypair.tf         # RSA key pair generation
├── compute.tf         # EC2 instance with Nginx user data
├── loadbalancer.tf    # ALB, target group, listener, IGW
├── database.tf        # RDS MySQL instance and subnet group
├── secrets.tf         # AWS Secrets Manager secret and data source
├── outputs.tf         # ALB DNS name and SSH command output
└── two-tier-key.pem   # Auto-generated SSH key (do NOT commit)
```

### File Explanations

| File | Purpose |
|---|---|
| `provider.tf` | Configures the AWS provider and deployment region |
| `variables.tf` | Defines input variables: region, instance type, DB credentials |
| `vpc.tf` | Creates the VPC, public subnets, private DB subnets |
| `security.tf` | Defines three security groups with least-privilege rules |
| `keypair.tf` | Generates RSA key pair and saves `.pem` file locally |
| `compute.tf` | Launches EC2 with Ubuntu 22.04 + Nginx via user data script |
| `loadbalancer.tf` | Provisions IGW, route table, ALB, target group, and listener |
| `database.tf` | Creates private RDS MySQL 8.0 instance with subnet group |
| `secrets.tf` | Creates Secrets Manager secret, seeds credentials, exposes data source |
| `outputs.tf` | Outputs the ALB DNS URL and ready-to-use SSH command |

---

## ⚙️ Terraform Design Approach

### 1️⃣ Infrastructure as Code

Terraform declaratively defines every AWS resource, enabling:
- Version-controlled infrastructure
- Repeatable deployments across environments
- Automated provisioning with no manual console steps
- Reduced human error in complex multi-resource setups

### 2️⃣ Two-Tier Network Isolation

The architecture separates concerns using VPC subnet tiers:
- **Public subnets** host the EC2 web server and ALB, reachable from the internet
- **Private subnets** host the RDS database, isolated with no public route

### 3️⃣ Least-Privilege Security Groups

Each layer only accepts traffic from the layer directly above it:
- ALB accepts HTTP from `0.0.0.0/0`
- EC2 accepts HTTP only from the ALB security group
- RDS accepts MySQL (3306) only from the EC2 security group

### 4️⃣ High Availability Design

The ALB spans two public subnets across `eu-west-2a` and `eu-west-2b`, and the RDS subnet group also covers both AZs — laying the groundwork for multi-AZ failover.

### 5️⃣ Secrets Manager for RDS Credentials

RDS credentials are stored encrypted in **AWS Secrets Manager** instead of plain-text variables. A new `secrets.tf` file creates the secret, seeds it with credentials on first apply, and exposes it as a data source. The `database.tf` file then reads the credentials directly from Secrets Manager — they never appear in terminal commands, CI/CD logs, or `.tf` files. Both `db_username` and `db_password` variables are marked `sensitive = true`, so they are redacted as `(sensitive value)` in all Terraform plan and apply output.

> 📸 **Secrets Manager Console Screenshot:**
<img width="1752" height="817" alt="image" src="https://github.com/user-attachments/assets/44af4060-4e31-4ff9-8c36-4506c45dc60c" />


---

## 🚀 Deployment Instructions

### Prerequisites
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with valid credentials
- AWS account with EC2, RDS, VPC, ELB, and **Secrets Manager** permissions

### Steps

**1. Clone the repository**
```bash
git clone https://github.com/your-username/terraform-aws-two-tier.git
cd terraform-aws-two-tier
```

**2. Initialize Terraform**
```bash
terraform init
```

**3. Validate Configuration**
```bash
terraform validate
```

**4. Review Execution Plan**
```bash
terraform plan -var="db_username=admin" -var="db_password=yourpassword"
```

> 🔒 Credentials will show as `(sensitive value)` in the plan output — this confirms redaction is working correctly.

**5. Apply Infrastructure**
```bash
terraform apply -var="db_username=admin" -var="db_password=yourpassword"
```

> ⚠️ RDS provisioning takes approximately **5–10 minutes**.

> 📸 **Sensitive Value Redaction Screenshot:**
<!-- TO ADD: Run terraform plan and take a screenshot showing (sensitive value) in the output → upload to GitHub and replace the line below -->
> ⚠️ *Replace this line with your terraform plan screenshot showing `(sensitive value)` redaction*

---

## 🔍 Terraform Deployment Output

After a successful `terraform apply`, you will see:

```
load_balancer_dns = "two-tier-lb-xxxxxxxxxxxx.eu-west-2.elb.amazonaws.com"
ssh_command       = "ssh -i two-tier-key.pem ubuntu@xx.xx.xx.xx"
```

> 📸 **Deployment Screenshot:**
<img width="952" height="120" alt="image" src="https://github.com/user-attachments/assets/1c3e1468-fefd-45ab-b69d-b0b59b346e24" />

---

## 🌐 Application Validation

Once Terraform completes deployment, copy the `load_balancer_dns` URL and open it in your browser:

```
http://two-tier-lb-xxxxxxxxxxxx.eu-west-2.elb.amazonaws.com
```

The Nginx web server responds with:

```
Hello from Terraform Web Server on Ubuntu
```

> 📸 **App Screenshot:**
<img width="1913" height="1017" alt="image" src="https://github.com/user-attachments/assets/876fb8e5-dd5a-4b95-b4dc-948917ee0afa" />

---

## 🔒 RDS Private Subnet Security Validation

A core design requirement of this architecture is that the RDS database is **only reachable from within the VPC** — specifically from the EC2 web server. It is not publicly accessible from the internet.

This was validated with two connection tests:

### ✅ Connection from EC2 — Allowed

```bash
# Step 1: SSH into EC2 using the Terraform output command
ssh -i two-tier-key.pem ubuntu@<public-ip>

# Step 2: From inside EC2, connect to RDS
mysql -h <rds-endpoint> -u admin -p
```

**Result:** Connection succeeds — `Welcome to the MySQL monitor` is returned.

### ❌ Connection from Local Machine — Denied

```bash
# Run from your laptop — NOT from EC2
mysql -h <rds-endpoint> -u admin -p
```

**Result:** Connection times out and is dropped. The RDS instance has `publicly_accessible = false` and the DB security group only permits traffic from the web security group.

> 📸 **RDS Security Validation Screenshot:**
<img width="1918" height="807" alt="image" src="https://github.com/user-attachments/assets/9d4d19ca-68e9-45ff-929c-ca5e7fb7ce1d" />

> *Left: MySQL connection from EC2 ✅ — Right: Connection from local machine ❌ (timeout)*

---

## 🔐 Security Notes

- `two-tier-key.pem` is auto-generated locally. **Never commit it to version control.**
- RDS credentials are stored encrypted in AWS Secrets Manager — never in `.tf` files or shell history.
- Both `db_username` and `db_password` are marked `sensitive = true` — they appear as `(sensitive value)` in all Terraform output.
- Add the following to your `.gitignore`:
```
two-tier-key.pem
.terraform/
terraform.tfstate
terraform.tfstate.backup
*.tfvars
```
- Port `22` (SSH) is open to `0.0.0.0/0`. **For production, restrict this to your IP.**

---

## 📊 Infrastructure Summary

| Component | Service Used |
|---|---|
| Networking | Amazon VPC, Subnets, IGW, Route Tables |
| Load Balancing | AWS Application Load Balancer (ALB) |
| Web Tier | Amazon EC2 (Ubuntu 22.04 + Nginx) |
| Database Tier | Amazon RDS (MySQL 8.0) |
| Credential Management | AWS Secrets Manager |
| Security | AWS Security Groups |
| Key Management | Terraform TLS Provider |
| Infrastructure Provisioning | Terraform |
| Authentication | AWS CLI |
| Region | eu-west-2 (London) |

---

## 🧠 Key Concepts Demonstrated

- Custom VPC design with public and private subnet tiers
- Application Load Balancer configuration and target group routing
- RDS deployment inside private subnets with multi-AZ subnet groups
- Least-privilege security group chaining (ALB → EC2 → RDS)
- EC2 user data for automated Nginx installation
- Terraform resource dependency management
- Auto-generated SSH key pairs using the TLS provider
- AWS Secrets Manager integration for encrypted credential handling
- `sensitive = true` variable flag for Terraform output redaction
- `jsonencode` / `jsondecode` for structured secret storage and retrieval
- Infrastructure as Code best practices

---

## 🏁 Project Outcomes

This project demonstrates the ability to:

- Design and deploy a multi-tier cloud architecture on AWS
- Implement network isolation using VPC subnets and security groups
- Provision a load-balanced web tier with an EC2 instance
- Deploy a private, non-publicly-accessible RDS database
- Validate private subnet security through connection testing
- Structure Terraform configurations across multiple logical files
- Apply cloud security best practices at the network level
- Manage secrets securely using AWS Secrets Manager via Terraform

---

## 🔮 Future Improvements

Potential enhancements:

- [ ] Auto Scaling Group to replace single EC2 instance
- [ ] Multi-AZ RDS for database high availability
- [ ] HTTPS with AWS Certificate Manager + Route 53
- [x] ~~Secrets Manager for RDS credentials instead of variables~~ ✅ Completed
- [ ] NAT Gateway for private subnet outbound access
- [ ] CloudWatch alarms for EC2 and RDS monitoring
- [ ] Terraform remote state with S3 + DynamoDB locking
- [ ] CI/CD pipeline with GitHub Actions

---

## 📄 Author

**Sanjog Shrestha**

---

## 📜 License

This project is intended for educational and portfolio purposes.
