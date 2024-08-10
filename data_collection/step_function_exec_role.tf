# IAM Role for Step Function Execution
resource "aws_iam_role" "step_function_execution_role" {
  name = "${var.resource_prefix}StepFunctionExecutionRole"
  path = "/"

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
}

# Policy for Glue Execution
resource "aws_iam_role_policy" "glue_execution_policy" {
  name   = "GlueExecution"
  role   = aws_iam_role.step_function_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:GetCrawler"
        ]
        Resource = "arn:aws:glue:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:crawler/${var.resource_prefix}*Crawler*"
      }
    ]
  })
}

# Policy for Lambda Invocation
resource "aws_iam_role_policy" "invoke_collection_lambda_policy" {
  name   = "InvokeCollectionLambda"
  role   = aws_iam_role.step_function_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = "arn:aws:lambda:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:function:${var.resource_prefix}*Lambda*"
      }
    ]
  })
}

# Policy for Synchronous Execution
resource "aws_iam_role_policy" "synchronous_execution_policy" {
  name   = "PolicyForSyncronousExecution"
  role   = aws_iam_role.step_function_execution_role.id
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
        Resource = "arn:aws:events:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForStepFunctionsExecutionRule"
      },
      {
        Effect = "Allow"
        Action = "states:StartExecution"
        Resource = "arn:aws:states:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.resource_prefix}*-StateMachine"
      },
      {
        Effect = "Allow"
        Action = [
          "states:DescribeExecution",
          "states:StopExecution"
        ]
        Resource = [
          "arn:aws:states:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:execution:*:*",
          "arn:aws:states:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:express:*:*:*"
        ]
      }
    ]
  })
}

# Policy for S3 Read Only Access
resource "aws_iam_role_policy" "s3_read_only_access_policy" {
  name   = "S3-ReadOnlyAccess"
  role   = aws_iam_role.step_function_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.s3_bucket.arn}/*"
      }
    ]
  })
}

# Data source for AWS region
data "aws_region" "region" {}

# Data source for AWS caller identity
data "aws_caller_identity" "current" {}

# Example S3 Bucket resource
resource "aws_s3_bucket" "s3_bucket" {
  bucket = "example-bucket"  # Replace with your bucket name
}

# Variables definition
variable "resource_prefix" {
  description = "Prefix for naming resources"
  type        = string
}
