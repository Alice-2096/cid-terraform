resource "aws_iam_role" "lambda_role_pricing" {
  name = "${local.resource_prefix}pricing-LambdaRole"

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
    name = "S3Access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:PutObject"
          ]
          Resource = "arn:aws:s3:::cid-data-${data.aws_caller_identity.current.account_id}/*"
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject"
          ]
          Resource = "arn:aws:s3:::aws-managed-cost-intelligence-dashboards-us-east-1-test/*"
        }
      ]
    })
  }

  inline_policy {
    name = "SSM"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ssm:GetParameter"
          ]
          Resource = "arn:aws:ssm:us-east-1::parameter/aws/service/global-infrastructure/regions/*/longName"
        }
      ]
    })
  }
}

data "archive_file" "lambda-pricing" {
  type        = "zip"
  source_file = "./scripts/pricing.py"
  output_path = "./scripts/pricing.zip"
}


resource "aws_lambda_function" "lambda_function_pricing" {
  function_name = "${local.resource_prefix}pricing-Lambda"
  description   = "Lambda function to retrieve pricing data"
  runtime       = "python3.10"
  handler       = "pricing.lambda_handler"
  filename      = "./scripts/pricing.zip"
  role          = aws_iam_role.lambda_role_trusted_advisor.arn
  memory_size   = 2880
  timeout       = 600

  environment {
    variables = {
      BUCKET_NAME       = "cid-data-${data.aws_caller_identity.current.account_id}"
      CODE_BUCKET       = "aws-managed-cost-intelligence-dashboards-us-east-1"
      DEST_PREFIX       = "pricing"
      RDS_GRAVITON_PATH = "cfn/data-collection/data/rds_graviton_mapping.csv"
      REGIONS           = "us-east-1"
    }
  }
}

resource "aws_cloudwatch_log_group" "log_group_pricing" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_function_pricing.function_name}"
  retention_in_days = 60
}

