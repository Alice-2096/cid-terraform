resource "aws_iam_role" "lambda_role_cost_anomaly" {
  name = "${local.resource_prefix}cost-anomaly-LambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
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
    name = "cost-anomaly-ManagementAccount-LambdaRole"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "sts:AssumeRole"
          Resource = "arn:aws:iam::*:role/CID-DC-Lambda-Assume-Role-Management-Account"
        }
      ]
    })
  }

  inline_policy {
    name = "S3Access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:PutObjectAcl"
          ]
          Resource = "arn:aws:s3:::cid-data-${data.aws_caller_identity.current.account_id}/*"
        },
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket"
          ]
          Resource = "arn:aws:s3:::cid-data-${data.aws_caller_identity.current.account_id}"
        }
      ]
    })
  }
}

data "archive_file" "lambda-cost-anomaly" {
  type        = "zip"
  source_file = "./scripts/cost_anomaly.py"
  output_path = "./scripts/cost_anomaly.zip"
}


resource "aws_lambda_function" "lambda_function_cost_anomaly" {
  function_name = "${local.resource_prefix}cost-anomaly-Lambda"
  description   = "Lambda function to retrieve cost anomaly data"
  runtime       = "python3.10"
  handler       = "cost_anomaly.lambda_handler"
  filename      = "./scripts/cost_anomaly.zip"
  role          = aws_iam_role.lambda_role_cost_anomaly.arn
  memory_size   = 2688
  timeout       = 600

  environment {
    variables = {
      BUCKET_NAME = "cid-data-${data.aws_caller_identity.current.account_id}"
      PREFIX      = "cost-anomaly"
      ROLE_NAME   = "CID-DC-Lambda-Assume-Role-Management-Account"
    }
  }
}

resource "aws_cloudwatch_log_group" "log_group_cost_anomaly" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_function_cost_anomaly.function_name}"
  retention_in_days = 60
}

