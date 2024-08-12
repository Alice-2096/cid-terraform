# Variables
variable "management_role_name" {
  description = "The name of the IAM role that will be deployed in the management account which can retrieve AWS Organization data."
  type        = string
}

variable "management_account_id" {
  description = "List of Payer IDs you wish to collect data for."
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for roles and resources."
  type        = string
}

variable "destination_bucket" {
  description = "Name of the S3 Bucket to be created to hold data information."
  type        = string
}

variable "destination_bucket_arn" {
  description = "ARN of the S3 Bucket that exists or needs to be created to hold rightsizing information."
  type        = string
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.resource_prefix}account-collector-LambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]

  inline_policy {
    name   = "AssumeManagementRole"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "sts:AssumeRole"
          Resource = "arn:aws:iam::*:role/${var.management_role_name}"
        }
      ]
    })
  }

  inline_policy {
    name   = "CloudWatch"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
          ]
          Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"
        }
      ]
    })
  }

  inline_policy {
    name   = "SSM"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "ssm:GetParameter"
          Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/cid/${var.resource_prefix}*"
        }
      ]
    })
  }

  inline_policy {
    name   = "Lambda"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "lambda:GetAccountSettings"
          Resource = "*"
        }
      ]
    })
  }

  inline_policy {
    name   = "S3-Access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Resource = "${var.destination_bucket_arn}/*"
        }
      ]
    })
  }
}

# Lambda Function
resource "aws_lambda_function" "account_collector" {
  function_name = "${var.resource_prefix}account-collector-Lambda"
  description    = "Lambda function to retrieve the account list"
  runtime        = "python3.10"
  role           = aws_iam_role.lambda_role.arn
  handler        = "index.lambda_handler"
  memory_size    = 2688
  timeout        = 600

  filename = "path/to/your/lambda/package.zip"  # Provide path to your Lambda deployment package

  environment {
    variables = {
      ROLE_NAME                     = var.management_role_name
      MANAGEMENT_ACCOUNT_IDS        = var.management_account_id
      RESOURCE_PREFIX               = var.resource_prefix
      BUCKET_NAME                   = var.destination_bucket
      PREDEF_ACCOUNT_LIST_KEY       = "account-list/account-list"
      LINKED_ACCOUNT_LIST_KEY       = "account-list/linked-account-list.json"
      PAYER_ACCOUNT_LIST_KEY        = "account-list/payer-account-list.json"
    }
  }

  # Note: You should have a valid zip file for Lambda function code
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.account_collector.function_name}"
  retention_in_days = 60
}

# Data source for region and account ID
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Output
output "lambda_function_name" {
  value = aws_lambda_function.account_collector.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.account_collector.arn
}
