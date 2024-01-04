# Step 1: Provider block

provider "aws" {
  region = "eu-central-1"
}

# Step 2: AWS ECR
resource "aws_ecr_repository" "my_ecr_repo" {
  name = "my-ecr-repo"
}

# # Step 3: Build Docker image, tag, and push to ECR
# # (You may need to have Docker installed on your machine for this step)
# # Use your own Dockerfile and context path
# resource "null_resource" "build_and_push_image" {
#   provisioner "local-exec" {
#     command = <<EOT
#       aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.my_ecr_repo.repository_url}
#       docker build -t ${aws_ecr_repository.my_ecr_repo.repository_url}:latest . --platform=linux/amd64
#       docker push ${aws_ecr_repository.my_ecr_repo.repository_url}:latest
#     EOT
#   }
# }

# Step 4: ECS cluster
resource "aws_ecs_cluster" "my_cluster" {
  name = "my-ecs-cluster"
}

# Step 5: ECS Task Definition
resource "aws_ecs_task_definition" "my_task_definition" {
  family                   = "my-task-family"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  # Reference the ECR image
  container_definitions = jsonencode([
    {
      name      = "my-container"
      image     = "${aws_ecr_repository.my_ecr_repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = var.container_port,
          hostPort      = var.container_port
        }
      ]
      # Other container settings...
    }
  ])
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  depends_on = [
    aws_ecr_repository.my_ecr_repo
  ]
}

# # Step 6: Load Balancer & Security Group
resource "aws_alb" "application_load_balancer" {
  name               = "my-alb"
  load_balancer_type = "application"
  subnets = [
    "${aws_default_subnet.default1.id}",
    "${aws_default_subnet.default2.id}",
    "${aws_default_subnet.default3.id}"
  ]
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "my_target_group" {
  name        = "my-target-group"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_default_vpc.default.id
}

resource "aws_lb_listener" "my_lb_listener" {
  load_balancer_arn = aws_alb.application_load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

# Step 7: ECS Service
resource "aws_ecs_service" "my_ecs_service" {
  name            = "my-ecs-service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.my_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 1 # Set the number of instances

  load_balancer {
    target_group_arn = aws_lb_target_group.my_target_group.arn
    container_name   = "my-container"
    container_port   = var.container_port
  }
  network_configuration {
    subnets          = ["${aws_default_subnet.default1.id}", "${aws_default_subnet.default2.id}", "${aws_default_subnet.default3.id}"]
    security_groups  = ["${aws_security_group.service_security_group.id}"]
    assign_public_ip = true
  }
  depends_on = [
    aws_ecs_cluster.my_cluster,
    aws_ecs_task_definition.my_task_definition
  ]
}

resource "aws_security_group" "service_security_group" {
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group_attachment" "my_target_group_attachment" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_ecs_service.my_ecs_service.id
}

# # Step 8: Clean up resources
# # Note: This is a simple cleanup example. Depending on your environment, you may need to extend this.
# resource "aws_ecs_service" "cleanup_ecs_service" {
#   name    = aws_ecs_service.my_ecs_service.name
#   cluster = aws_ecs_service.my_ecs_service.cluster

#   depends_on = [
#     aws_lb.my_load_balancer,
#     aws_lb_listener.my_lb_listener,
#     aws_lb_target_group_attachment.my_target_group_attachment,
#   ]

#   lifecycle {
#     ignore_changes = [
#       task_definition,
#       desired_count,
#       launch_type,
#       network_configuration,
#     ]
#   }
# }

# resource "aws_lb" "cleanup_lb" {
#   name = aws_lb.my_load_balancer.name
# }

# resource "aws_ecr_repository" "cleanup_ecr_repo" {
#   name = aws_ecr_repository.my_ecr_repo.name
# }

# # Additional cleanup steps may be needed depending on your specific setup

