terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # You'll need to create this S3 bucket first
    bucket = "taskflow-terraform-state"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# ECR Repositories
resource "aws_ecr_repository" "backend" {
  name = "${var.app_name}-backend"
}

resource "aws_ecr_repository" "frontend" {
  name = "${var.app_name}-frontend"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.app_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-${count.index + 1}"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.app_name}-public-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "app" {
  name        = "${var.app_name}-sg"
  description = "Security group for TaskFlow application"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-sg"
  }
}

# ALB
resource "aws_lb" "main" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.app_name}-alb"
  }
}

# Target Group for Frontend
resource "aws_lb_target_group" "frontend" {
  name        = "${var.app_name}-frontend"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Target Group for Backend
resource "aws_lb_target_group" "backend" {
  name        = "${var.app_name}-backend"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener for Frontend
resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# Listener Rule for Backend API
resource "aws_lb_listener_rule" "backend" {
  listener_arn = aws_lb_listener.frontend.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Task Definition - Backend
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.app_name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name  = "backend"
    image = "${aws_ecr_repository.backend.repository_url}:latest"
    portMappings = [{
      containerPort = 5000
      hostPort      = 5000
      protocol      = "tcp"
    }]
    environment = [
      {
        name  = "NODE_ENV"
        value = "production"
      },
      {
        name  = "PORT"
        value = "5000"
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.main.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "backend"
      }
    }
  }])
}

# Task Definition - Frontend
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.app_name}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([{
    name  = "frontend"
    image = "${aws_ecr_repository.frontend.repository_url}:latest"
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
    environment = [
      {
        name  = "VITE_API_URL"
        value = "/api"
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.main.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "frontend"
      }
    }
  }])
}

# ECS Service - Backend
resource "aws_ecs_service" "backend" {
  name            = "${var.app_name}-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.app.id]
    subnets         = aws_subnet.public[*].id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = 5000
  }

  depends_on = [aws_lb_listener_rule.backend]
}

# ECS Service - Frontend
resource "aws_ecs_service" "frontend" {
  name            = "${var.app_name}-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.app.id]
    subnets         = aws_subnet.public[*].id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }
}

# IAM Role for ECS
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.app_name}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "main" {
  name = "/ecs/${var.app_name}"
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Outputs
output "alb_url" {
  description = "ALB Public URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "backend_ecr_url" {
  description = "Backend ECR Repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_url" {
  description = "Frontend ECR Repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}