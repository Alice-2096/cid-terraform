# IAM Role for the Lambda function
resource "aws_iam_role" "lambda_analytics_role" {
  name = "${var.resource_prefix}analytics-role"
  path = "/${var.resource_prefix}/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach managed policy to the role
resource "aws_iam_role_policy_attachment" "lambda_analytics_policy" {
  role       = aws_iam_role.lambda_analytics_role.name
  policy_arn  = "arn:${data.aws_partition.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function
resource "aws_lambda_function" "lambda_analytics" {
  function_name = "${var.resource_prefix}analytics-Lambda"
  description    = "Lambda function to collect general deployment metrics"
  runtime        = "python3.10"
  handler        = "index.lambda_handler"
  memory_size    = 128
  timeout        = 15
  role           = aws_iam_role.lambda_analytics_role.arn

  environment {
    variables = {
      CID_ANALYTICS_ENDPOINT = "https://cid.workshops.aws.dev/adoption-tracking"
    }
  }
}

# Data source for AWS partition
data "aws_partition" "partition" {}
