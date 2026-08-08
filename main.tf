resource "random_id" "suffix" {
  byte_length = 4
}

resource "random_integer" "listener_priority" {
  min = 1000
  max = 49000
}

data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = "mlops-workshop-krysha-data1"
    key    = "mlopserver/networking/terraform.tfstate"
    region = "eu-west-1"
  }
}

data "terraform_remote_state" "loadbalancer" {
  backend = "s3"

  config = {
    bucket = "mlops-workshop-krysha-data1"
    key    = "mlopserver/loadbalancer/terraform.tfstate"
    region = "eu-west-1"
  }
}

resource "aws_ecs_cluster" "this" {
  name = "${var.cluster_name}-${var.roll_no}-${random_id.suffix.hex}"

  tags = {
    Name = "${var.cluster_name}-${var.roll_no}-${random_id.suffix.hex}"
  }
}

resource "aws_iam_role" "task_execution" {
  name = "ecs-task-execution-${var.roll_no}-${random_id.suffix.hex}"

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

resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_security_group" "ecs" {
  name        = "ecs-service-sg-${var.roll_no}-${random_id.suffix.hex}"
  description = "Security group for ECS tasks behind the ALB"
  vpc_id      = data.terraform_remote_state.networking.outputs.network_vpc_id

  ingress {
    description     = "Allow traffic from the ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.loadbalancer.outputs.load_balancer_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-service-sg-${var.roll_no}-${random_id.suffix.hex}"
  }
}

resource "aws_lb_target_group" "ecs_task_tg" {
  name        = substr("${var.service_name}-tg-${var.roll_no}-${random_id.suffix.hex}", 0, 32)
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.terraform_remote_state.networking.outputs.network_vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.service_name}-tg-${var.roll_no}-${random_id.suffix.hex}"
  }
}

data "aws_lb_listener" "http" {
  load_balancer_arn = data.terraform_remote_state.loadbalancer.outputs.load_balancer_arn
  port              = 80
}

resource "aws_lb_listener_rule" "per_run" {
  listener_arn = data.aws_lb_listener.http.arn
  priority     = random_integer.listener_priority.result

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_task_tg.arn
  }

  condition {
    path_pattern {
      values = ["/${var.roll_no}/*"]
    }
  }
}

resource "aws_ecs_task_definition" "churn" {
  family                   = "churn-task-${var.roll_no}-${random_id.suffix.hex}"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "churn"
      image     = var.container_image
      essential = true
      environment = [
        {
          name  = "MLFLOW_TRACKING_URI"
          value = var.mlflow_tracking_uri
        }
      ]
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "churn" {
  name            = "${var.service_name}-${var.roll_no}-${random_id.suffix.hex}"
  cluster         = aws_ecs_cluster.this.id
  launch_type     = "FARGATE"
  desired_count   = var.desired_count
  task_definition = aws_ecs_task_definition.churn.arn

  network_configuration {
    subnets          = data.terraform_remote_state.networking.outputs.network_public_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_task_tg.arn
    container_name   = "churn"
    container_port   = var.container_port
  }

  depends_on = [
    aws_iam_role_policy_attachment.task_execution_policy
  ]
}
