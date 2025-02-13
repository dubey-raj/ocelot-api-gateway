### Create Amazon ECS Cluster

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "appkms" {
  statement {
    # https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
      "kms*"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html
    sid    = "Allow Cloudwatch access to KMS Key"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.Region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = [
      "*"
    ]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:aws:logs:${var.Region}:${data.aws_caller_identity.current.account_id}:*"
      ]
    }
  }
}

# Create KMS key for solution
resource "aws_kms_key" "kms_key" {
  description             = "KMS key to secure various aspects of an example Microsoft .NET web application"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.appkms.json

  tags = {
    Name         = format("%s-%s-%s", var.Application, "kms", var.EnvCode)
    resourcetype = "security"
    codeblock    = "ecscluster"
  }
}

# Create KMS Alias. Only used in this context to provide a friendly display name
resource "aws_kms_alias" "kms_alias" {
  name          = "alias/${var.Application}"
  target_key_id = aws_kms_key.kms_key.key_id
}

# Create CloudWatch log group for ECS logs 
resource "aws_cloudwatch_log_group" "ecscluster_logs" {
  name              = format("%s/%s/%s", "ecscluster", var.Application, var.Region)
  retention_in_days = 90
  kms_key_id        = aws_kms_key.kms_key.arn

  tags = {
    Name         = format("%s/%s/%s", "ecscluster", var.Application, var.Region)
    resourcetype = "monitor"
    codeblock    = "ecscluster"
  }
}

# Create CloudWatch log group for Application logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = format("%s/%s/%s", "ecs",var.Application, var.EnvCode)
  retention_in_days = 30
  kms_key_id        = aws_kms_key.kms_key.arn

  tags = {
    Name         = format("%s/%s/%s", "ecs",var.Application, var.EnvCode)
    resourcetype = "monitor"
    codeblock    = "ecscluster"
  }
}

# Create Amazon ECS cluster 
resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.Application

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.kms_key.arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecscluster_logs.name
      }
    }
  }

  tags = {
    Name         = format("%s-%s", var.Application, var.EnvCode)
    resourcetype = "storage"
    codeblock    = "ecscluster"
  }
}

# Establish IAM Role with permissions for Amazon ECS to access Amazon ECR for image pulling and CloudWatch for logging
resource "aws_iam_role" "ecstaskexec" {
  name = format("%s-%s-%s", "ecstaskexec", var.Application, var.Region)
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name  = format("%s-%s-%s", "ecstaskexec", var.Application, var.Region)
    rtype = "security"
  }
}

resource "aws_iam_role_policy" "ecstaskexecaccess" {
  name = format("%s-%s-%s", "ecstaskexec", var.Application, var.Region)
  role = aws_iam_role.ecstaskexec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # https://docs.aws.amazon.com/AmazonECR/latest/userguide/security_iam_id-based-policy-examples.html
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Effect   = "Allow"
        Resource = ["*"]
      },
      {
        # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/instance_IAM_role.html#cwl_iam_policy
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}