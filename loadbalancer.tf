# -----------------------------------------------------------------------------
# Networking & Load Balancing - IGW, Route Table, ALB, Target Group, Listener
# -----------------------------------------------------------------------------
# Internet Gateway enables public internet access. Route table sends traffic
# to the IGW. ALB distributes HTTP traffic across targets.

# Internet Gateway - Attaches to VPC for public internet connectivity
# Purpose: Enables subnets with IGW route to send/receive traffic from internet
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "two-tier-igw"
  })
}

# Public Route Table - Defines how traffic exits the VPC
# Purpose: Routes 0.0.0.0/0 (all traffic) through IGW so public subnets can reach internet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Default route: send all non-local traffic to the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(local.common_tags, {
    Name = "public-route-table"
  })
}

# Route Table Association - Links public subnet 1 to the public route table
# Purpose: Subnet inherits the 0.0.0.0/0 route; instances can reach internet
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

# Route Table Association - Links public subnet 2 to the public route table
# Purpose: Both public subnets use the same routing rules
resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Application Load Balancer - Distributes HTTP traffic across targets
# Purpose: Single entry point (DNS name); health checks; spreads across AZs
resource "aws_lb" "app_lb" {
  name               = "two-tier-lb"
  internal           = false # Public-facing; use true for internal-only
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb_sg.id]

  # ALB must span at least 2 AZs for high availability
  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  tags = merge(local.common_tags, {
    Name = "two-tier-lb"
  })
}

# Target Group - Group of EC2 instances that receive traffic from ALB
# Purpose: ALB forwards requests here; health checks determine which targets are healthy
resource "aws_lb_target_group" "tg" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "two-tier-tg"
  })
}

# Listener - Binds ALB to a port and defines default action
# Purpose: Listens on port 80; forwards all HTTP traffic to the target group
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  # Default action when a request matches this listener
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# Target Group Attachment - Registers EC2 instance with the target group
# Purpose: ALB can now send traffic to this instance; health checks will run
resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web.id
  port             = 80
}
