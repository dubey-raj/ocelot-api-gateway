# Create Application Load Balancer
# WARNING: Consider implementing AWS WAFv2 in front of an Application Load Balancer for production environments

resource "aws_lb" "alb" {
  name                       = format("%s-%s-%s", "alb", var.Application, var.EnvCode)
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.web01.id]
  subnets                    = local.pub_subnet_ids_list
  drop_invalid_header_fields = true

  access_logs {
    bucket  = aws_s3_bucket.alblogs.id
    prefix = "albaccesslogs"
    enabled = false
  }

  tags = {
    Name  = format("%s-%s-%s", "alb",var.Application, var.EnvCode)
    rtype = "network"
  }
}

# Output ALB DNS name for GitHub Actions job output
output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

# Create ALB listener
# WARNING: Consider changing port to 443 and protocol to HTTPS for production environments 
resource "aws_lb_listener" "alb_listener_http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }

  tags = {
    Name  = format("%s-%s-%s-%s", "lbl", var.Application, var.EnvCode, var.Region)
    rtype = "network"
  }
}

resource "aws_lb_listener" "alb_listener_https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.SSLCertificateARN

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-target-group.arn
  }

  tags = {
    Name  = format("%s-%s-%s-%s", "lbl", var.Application, var.EnvCode, var.Region)
    rtype = "network"
  }
}

# Define ALB Target Group
# WARNING: Lifecyle and name_prefix added for testing. Issue discussed here https://github.com/hashicorp/terraform-provider-aws/issues/16889
resource "aws_lb_target_group" "alb-target-group" {
  name_prefix                   = "tg-"
  port                          = 80
  protocol                      = "HTTP"
  target_type                   = "ip"
  vpc_id                        = data.aws_vpc.selected.id
  load_balancing_algorithm_type = "round_robin"

  health_check {
    path    = "/healthz"
    matcher = "200"
  }

  stickiness {
    enabled         = true
    type            = "lb_cookie"
    cookie_duration = 86400
  }

  lifecycle {
    create_before_destroy = true
  }


  tags = {
    Name  = format("%s-%s-%s-%s", "albtg", var.Application, var.EnvCode, var.Region)
    rtype = "network"
  }
}

# Create Security Groups
resource "aws_security_group" "web01" {
  name        = format("%s-%s-%s-%s", "scg", "web", var.Application, var.EnvCode)
  description = "Web Security Group"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "Web Inbound https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Web Inbound http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Web Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name         = format("%s-%s-%s-%s", "scg", "web", var.Application, var.EnvCode)
    resourcetype = "security"
    codeblock    = "network-3tier"
  }
}

resource "aws_security_group" "app01" {
  name        = format("%s-%s-%s-%s", "scg", "app", var.Application, var.EnvCode)
  description = "Application Security Group"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description     = "Application Inbound"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.web01.id]
    self            = true
  }

  egress {
    description = "Application Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name         = format("%s-%s-%s-%s", "scg", "app", var.Application, var.EnvCode)
    resourcetype = "security"
    codeblock    = "network-3tier"
  }
}