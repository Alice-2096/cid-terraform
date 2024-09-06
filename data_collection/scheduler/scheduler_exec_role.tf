locals {
  resource_prefix = "CID-DC-"
}

# IAM Role for Scheduler Execution
resource "aws_iam_role" "scheduler_execution_role" {
  name = "${local.resource_prefix}SchedulerExecutionRole"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Policy for Executing State Machine
resource "aws_iam_role_policy" "execute_state_machine_policy" {
  name = "ExecuteStateMachine"
  role = aws_iam_role.scheduler_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = "arn:aws:states:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:stateMachine/${local.resource_prefix}*StateMachine"
      }
    ]
  })
}

# Policy for Executing Lambda Functions
resource "aws_iam_role_policy" "execute_lambda_policy" {
  name = "ExecuteLambda"
  role = aws_iam_role.scheduler_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = "arn:aws:lambda:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:function:${local.resource_prefix}*"
      }
    ]
  })
}

