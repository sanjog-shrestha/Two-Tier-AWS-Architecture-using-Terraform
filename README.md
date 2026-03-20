# 🏗️ Two-Tier AWS Architecture with Terraform

## 📌 Overview

This project demonstrates how to deploy a **production-style two-tier web application** on **Amazon Web Services (AWS)** using **HashiCorp Terraform** Infrastructure as Code (IaC).

Terraform provisions and configures all required AWS resources automatically — including a custom VPC, public/private subnets, an Application Load Balancer, an Auto Scaling Group web tier, and a private RDS MySQL database — enabling repeatable and version-controlled infrastructure deployments.

The infrastructure includes:
- Custom VPC with public and private subnets across 2 Availability Zones
- Application Load Balancer (ALB)
- Auto Scaling Group (ASG) with Launch Template — replaces single EC2 instance
- CPU-based automatic scaling via CloudWatch alarms
- RDS MySQL database (private, not publicly accessible)
- Security groups with least-privilege access
- Auto-generated RSA SSH key pair
- AWS Secrets Manager for encrypted RDS credential management

This project highlights cloud networking, multi-tier architecture design, auto-scaling, infrastructure security, and DevOps deployment practices.

---

## 🏗️ Architecture

```
Internet
    ↓ HTTP :80
Application Load Balancer (ALB)
    ↓ (auto-registered targets)
┌─────────────────────────────────────────┐
│             VPC (10.0.0.0/16)           │
│                                         │
│  Public Subnet 1      Public Subnet 2   │
│  (eu-west-2a)         (eu-west-2b)      │
│  WebServer-ASG-1      WebServer-ASG-2   │
│       ↓                    ↓            │
│          Private Subnets                │
│  Private Subnet 1    Private Subnet 2   │
│  (eu-west-2a)        (eu-west-2b)       │
│          └──── RDS MySQL ────┘          │
└─────────────────────────────────────────┘
         ↑ scale-out @ CPU > 70%
         ↓ scale-in  @ CPU < 30%
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
| Target Group + Listener | Forwards HTTP traffic to ASG instances on port 80 |
| Launch Template | Instance blueprint — AMI, type, user data, SG, key pair |
| Auto Scaling Group | Maintains 1–3 instances across both public subnets |
| Scale-Out Policy | Adds 1 instance when avg CPU > 70% for 2 minutes |
| Scale-In Policy | Removes 1 instance when avg CPU < 30% for 2 minutes |
| CloudWatch Alarms (×2) | Triggers scale-out and scale-in policies |
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
├── variables.tf       # Input variable definitions (incl. ASG sizing)
├── vpc.tf             # VPC, subnets, route tables
├── security.tf        # Security groups (ALB, web, DB)
├── keypair.tf         # RSA key pair generation
├── compute.tf         # Launch Template, ASG, scaling policies, CloudWatch alarms
├── loadbalancer.tf    # ALB, target group, listener, IGW
├── database.tf        # RDS MySQL instance and subnet group
├── secrets.tf         # AWS Secrets Manager secret and data source
├── outputs.tf         # ALB DNS name, ASG name, launch template ID
└── two-tier-key.pem   # Auto-generated SSH key (do NOT commit)
```

### File Explanations

| File | Purpose |
|---|---|
| `provider.tf` | Configures the AWS provider and deployment region |
| `variables.tf` | Defines input variables: region, instance type, DB credentials, ASG sizing |
| `vpc.tf` | Creates the VPC, public subnets, private DB subnets |
| `security.tf` | Defines three security groups with least-privilege rules |
| `keypair.tf` | Generates RSA key pair and saves `.pem` file locally |
| `compute.tf` | Launch Template + ASG + scaling policies + CloudWatch alarms |
| `loadbalancer.tf` | Provisions IGW, route table, ALB, target group, and listener |
| `database.tf` | Creates private RDS MySQL 8.0 instance with subnet group |
| `secrets.tf` | Creates Secrets Manager secret, seeds credentials, exposes data source |
| `outputs.tf` | Outputs ALB DNS URL, ASG name, capacity summary, launch template ID |

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
- **Public subnets** host the ASG web instances and ALB, reachable from the internet
- **Private subnets** host the RDS database, isolated with no public route

### 3️⃣ Least-Privilege Security Groups

Each layer only accepts traffic from the layer directly above it:
- ALB accepts HTTP from `0.0.0.0/0`
- EC2 accepts HTTP only from the ALB security group
- RDS accepts MySQL (3306) only from the EC2 security group

### 4️⃣ High Availability Design

The ALB spans two public subnets across `eu-west-2a` and `eu-west-2b`. The ASG distributes instances across both subnets, and the RDS subnet group also covers both AZs — laying the groundwork for multi-AZ database failover.

### 5️⃣ Secrets Manager for RDS Credentials

RDS credentials are stored encrypted in **AWS Secrets Manager** instead of plain-text variables. The `secrets.tf` file creates the secret, seeds it with credentials on first apply, and exposes it as a data source. The `database.tf` file reads credentials directly from Secrets Manager — they never appear in terminal commands, CI/CD logs, or `.tf` files. Both `db_username` and `db_password` are marked `sensitive = true`, so they are redacted as `(sensitive value)` in all Terraform plan and apply output.

> 📸 **Secrets Manager Console Screenshot:**
<img width="1752" height="817" alt="image" src="https://github.com/user-attachments/assets/44af4060-4e31-4ff9-8c36-4506c45dc60c" />

### 6️⃣ Auto Scaling Group

The single EC2 instance is replaced by an `aws_launch_template` and `aws_autoscaling_group`. The ASG maintains a desired number of healthy instances at all times, automatically replacing any that fail their ALB health checks, and scales in or out based on CPU utilisation.

| Condition | Duration | Action | Cooldown |
|---|---|---|---|
| Avg CPU > 70% | 2 minutes | Add 1 instance | 300 seconds |
| Avg CPU < 30% | 2 minutes | Remove 1 instance | 300 seconds |
| Instance fails ELB health check | Immediate | Replace instance | — |
| Instance count < `min_size` | Immediate | Launch replacement | — |

`health_check_type = "ELB"` is used rather than the default `"EC2"` mode — an instance must return HTTP 200 on the target group health check path before the ASG considers it healthy, ensuring failed application instances are replaced and not just running ones.

### 7️⃣ Secrets Manager — Destroy/Re-Apply Fix

AWS Secrets Manager schedules deleted secrets for a 7-day recovery window by default. Re-applying after a `terraform destroy` fails because the secret name is still reserved. This is resolved by setting `recovery_window_in_days = 0` in `secrets.tf`, which allows Terraform to delete and recreate the secret immediately without naming conflicts.

```hcl
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "two-tier/rds/credentials"
  description             = "RDS MySQL credentials for the two-tier architecture"
  recovery_window_in_days = 0
  ...
}
```

If you encounter this error on an existing deployment before adding the fix, unblock yourself immediately with:

```bash
aws secretsmanager delete-secret \
  --secret-id "two-tier/rds/credentials" \
  --force-delete-without-recovery \
  --region eu-west-2
```

---

## 🚀 Deployment Instructions

### Prerequisites
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with valid credentials
- AWS account with EC2, RDS, VPC, ELB, Auto Scaling, CloudWatch, and Secrets Manager permissions

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
load_balancer_dns  = "two-tier-lb-xxxxxxxxxxxx.eu-west-2.elb.amazonaws.com"
asg_name           = "two-tier-web-asg"
asg_capacity       = "min=1  desired=2  max=3"
launch_template_id = "lt-XXXXXXXXXXXXXXXXX"
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

> ⚠️ The ALB may take 60–90 seconds to complete initial health checks before marking ASG instances as healthy.

> 📸 **App Screenshot:**
<img width="1913" height="1017" alt="image" src="https://github.com/user-attachments/assets/876fb8e5-dd5a-4b95-b4dc-948917ee0afa" />

---

## 🔒 RDS Private Subnet Security Validation

A core design requirement is that the RDS database is **only reachable from within the VPC** — specifically from the web security group. It is not publicly accessible from the internet.

This was validated with two connection tests:

### ✅ Connection from EC2 — Allowed

```bash
# Step 1: Get the IP of a running ASG instance
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=WebServer-ASG" "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].PublicIpAddress" \
  --output text

# Step 2: SSH into the instance
ssh -i two-tier-key.pem ubuntu@<public-ip>

# Step 3: From inside EC2, connect to RDS
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
- `recovery_window_in_days = 0` is set on the Secrets Manager secret to allow clean destroy/re-apply cycles without naming conflicts.
- There is no longer a fixed EC2 public IP — SSH access requires looking up an ASG instance IP first (see RDS validation section above).
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
| Web Tier | Auto Scaling Group + Launch Template (Ubuntu 22.04 + Nginx) |
| Auto Scaling | AWS Auto Scaling + CloudWatch CPU Alarms |
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
- Auto Scaling Group with Launch Template for dynamic web tier capacity
- CPU-based automatic scaling with CloudWatch alarms and cooldown policies
- `health_check_type = "ELB"` for application-level instance health enforcement
- RDS deployment inside private subnets with multi-AZ subnet groups
- Least-privilege security group chaining (ALB → EC2 → RDS)
- EC2 user data for automated Nginx installation
- Terraform resource dependency management
- Auto-generated SSH key pairs using the TLS provider
- AWS Secrets Manager integration for encrypted credential handling
- `sensitive = true` variable flag for Terraform output redaction
- `recovery_window_in_days = 0` for clean destroy/re-apply cycles
- `jsonencode` / `jsondecode` for structured secret storage and retrieval
- Infrastructure as Code best practices

---

## 🏁 Project Outcomes

This project demonstrates the ability to:

- Design and deploy a multi-tier cloud architecture on AWS
- Implement network isolation using VPC subnets and security groups
- Replace a single EC2 instance with a resilient Auto Scaling Group
- Configure CPU-based automatic scaling with CloudWatch and ASG policies
- Deploy a private, non-publicly-accessible RDS database
- Validate private subnet security through connection testing
- Structure Terraform configurations across multiple logical files
- Apply cloud security best practices at the network level
- Manage secrets securely using AWS Secrets Manager via Terraform
- Handle Secrets Manager destroy/re-apply lifecycle correctly

---

## 🔮 Future Improvements

Potential enhancements:

- [x] ~~Auto Scaling Group to replace single EC2 instance~~ ✅ Completed
- [x] ~~Secrets Manager for RDS credentials instead of variables~~ ✅ Completed
- [ ] Multi-AZ RDS for database high availability
- [ ] HTTPS with AWS Certificate Manager + Route 53
- [ ] NAT Gateway for private subnet outbound access
- [ ] CloudWatch dashboard for ASG, ALB, and RDS metrics
- [ ] Terraform remote state with S3 + DynamoDB locking
- [ ] CI/CD pipeline with GitHub Actions

---

## 📄 Author

**Sanjog Shrestha**

---

## 📜 License

This project is intended for educational and portfolio purposes.
