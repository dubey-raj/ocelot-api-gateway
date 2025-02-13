### Create Amazon ECS task definition and service
# Create Amazon ECS task definition
resource "aws_ecs_task_definition" "ecs-task-definition" {
  family                   = format("%s-%s", var.Application, var.EnvCode)
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecstaskexec.arn

  container_definitions = jsonencode([
    {
      name                   =  var.Application
      image                  = format("%s:%s",var.ArtifactoryRepo, var.ImageTag)
      cpu                    = 256
      memory                 = 512
      essential              = true
      readonlyRootFilesystem = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      logconfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "${aws_cloudwatch_log_group.app_logs.name}",
          awslogs-region        = "${var.Region}",
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# Create Amazon ECS task service
resource "aws_ecs_service" "ecs-service" {
  name            = format("%s-%s", var.Application, var.EnvCode)
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs-task-definition.arn
  launch_type     = "FARGATE"
  desired_count   = 2
  propagate_tags  = "TASK_DEFINITION"


  network_configuration {
    subnets         = local.pvt_subnet_ids_list
    security_groups = [aws_security_group.app01.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.alb-target-group.arn
    container_name   = var.Application
    container_port   = 8080
  }

  tags = {
    Name  = format("%s-%s", var.Application, var.EnvCode)
    rtype = "ecsservice"
  }
}