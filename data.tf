resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default1" {
  availability_zone = "eu-central-1a"
}

resource "aws_default_subnet" "default2" {
  availability_zone = "eu-central-1b"
}

resource "aws_default_subnet" "default3" {
  availability_zone = "eu-central-1c"
}

# ECS task execution role data
data "aws_iam_policy_document" "ecs_task_execution_role" {
  version = "2012-10-17"
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}