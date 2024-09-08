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

  inline_policy {
    name = "ExecuteStateMachine"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "states:StartExecution"
          Resource = "arn:aws:states:us-east-1:${data.aws_caller_identity.current.account_id}:stateMachine:CID-DC-*StateMachine"
        }
      ]
    })
  }

  inline_policy {
    name = "ExecuteLambda"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:CID-DC-*"
        }
      ]
    })
  }
}

