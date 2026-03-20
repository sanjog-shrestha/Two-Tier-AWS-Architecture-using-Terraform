# -----------------------------------------------------------------------------
# Compute - Launch Template + Auto Scaling Group
# -----------------------------------------------------------------------------
# The single aws_instance is replaced by an aws_launch_template and an
# aws_autoscaling_group. The launch template carries all instance-level
# configuration (AMI, type, user data, SG, key). The ASG uses it to
# launch and manage instances across both public subnets automatically.

# [NEW - ASG] Launch Template - Blueprint for every ASG instance.
# Replaces the previous aws_instance resource entirely.
resource "aws_launch_template" "web_lt" {
  name_prefix   = "two-tier-web-"
  image_id      = "ami-018ff7ece22bf96db" # Ubuntu 22.04 LTS - eu-west-2
  instance_type = var.instance_type

  key_name = aws_key_pair.generated_key.key_name

  # [NEW - ASG] network_interfaces block replaces subnet_id + associate_public_ip_address
  # on aws_instance. Public IP required so instances can reach apt outbound.
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
  }

  # [NEW - ASG] base64encode() is required — Launch Templates expect
  # base64-encoded user data, unlike the raw heredoc on aws_instance.
  user_data = base64encode(<<-EOF
    #!/bin/bash

    # Force IPv4 for apt (avoids IPv6 issues in some VPCs)
    echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

    # Wait for apt lock to release (cloud-init may hold it on first boot)
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
  )

  # Tag every EC2 instance launched by this template
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "WebServer-ASG"
    })
  }

  # Propagate tags to EBS volumes attached to ASG instances
  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "WebServer-ASG-Volume"
    })
  }

  tags = merge(local.common_tags, {
    Name = "two-tier-launch-template"
  })
}

# [NEW - ASG] Auto Scaling Group - Manages the fleet of web instances.
# Spans both public subnets for AZ redundancy. Instance count is controlled
# by the three asg_* variables defined in variables.tf.
resource "aws_autoscaling_group" "web_asg" {
  name = "two-tier-web-asg"

  vpc_zone_identifier = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  # Wires the ASG to the ALB target group.
  # Replaces aws_lb_target_group_attachment in loadbalancer.tf.
  # Instances are auto-registered on launch and deregistered on termination.
  target_group_arns = [aws_lb_target_group.tg.arn]

  # ELB mode means the instance must pass the ALB health check (HTTP 200)
  # before the ASG considers it healthy — stricter than EC2 mode.
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "WebServer-ASG"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }
}

# [NEW - ASG] Scale-Out Policy - Adds 1 instance when CPU alarm fires.
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out"
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300 # seconds before another scale-out can trigger
}

# [NEW - ASG] Scale-In Policy - Removes 1 instance when CPU alarm fires.
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in"
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

# [NEW - ASG] CloudWatch Alarm - Triggers scale-out when avg CPU > 70% for 2 minutes.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "two-tier-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out when average CPU exceeds 70% for 2 minutes"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}

# [NEW - ASG] CloudWatch Alarm - Triggers scale-in when avg CPU < 30% for 2 minutes.
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "two-tier-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale in when average CPU drops below 30% for 2 minutes"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]
}