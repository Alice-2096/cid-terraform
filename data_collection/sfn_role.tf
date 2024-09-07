resource "aws_iam_role" "step_function_execution_role" {
  name = "${local.resource_prefix}StepFunctionExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "GlueExecution"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "glue:StartCrawler",
            "glue:GetCrawler"
          ]
          Resource = "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:crawler/${local.resource_prefix}*Crawler*"
        }
      ]
    })
  }

  inline_policy {
    name = "InvokeCollectionLambda"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:${local.resource_prefix}*Lambda*"
        }
      ]
    })
  }

  inline_policy {
    name = "InvokeAccountCollector"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "lambda:InvokeFunction"
          Resource = "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:CID-DC-account-collector-Lambda"
        }
      ]
    })
  }

  inline_policy {
    name = "PolicyForSyncronousExecution"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "events:PutTargets",
            "events:DescribeRule",
            "events:PutRule"
          ]
          Resource = "arn:aws:events:us-east-1:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForStepFunctionsExecutionRule"
        },
        {
          Effect   = "Allow"
          Action   = "states:StartExecution"
          Resource = "arn:aws:states:us-east-1:${data.aws_caller_identity.current.account_id}:stateMachine:${local.resource_prefix}*-StateMachine"
        },
        {
          Effect = "Allow"
          Action = [
            "states:DescribeExecution",
            "states:StopExecution"
          ]
          Resource = [
            "arn:aws:states:us-east-1:${data.aws_caller_identity.current.account_id}:execution:*:*",
            "arn:aws:states:us-east-1:${data.aws_caller_identity.current.account_id}:express:*:*:*"
          ]
        }
      ]
    })
  }

  inline_policy {
    name = "S3-ReadOnlyAccess"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject"
          ]
          Resource = "arn:aws:s3:::cid-data-${data.aws_caller_identity.current.account_id}/*"
        }
      ]
    })
  }
}

