# -----------------------------------------------------------------------------
# Networking & Load Balancing - IGW, Route Table, ALB, Target Group, Listener
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "two-tier-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(local.common_tags, {
    Name = "public-route-table"
  })
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_lb" "app_lb" {
  name               = "two-tier-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  tags = merge(local.common_tags, {
    Name = "two-tier-lb"
  })
}

# Switched from name to name_prefix so Terraform can recreate
# the target group cleanly without naming conflicts if properties change.
# Added explicit health_check block — required for ELB-mode health checks
# used by the ASG (health_check_type = "ELB" in compute.tf).
resource "aws_lb_target_group" "tg" {
  name_prefix = "tt-tg-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name = "two-tier-tg"
  })
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

