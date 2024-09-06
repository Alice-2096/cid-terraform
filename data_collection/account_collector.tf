##################################### Lambda account collector ############################################
resource "aws_iam_role" "lambda_role" {
  name = "CID-DC-account-collector-LambdaRole"

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
    name = "AssumeManagementRole"
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
    name = "CloudWatch"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
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
    name = "SSM"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "ssm:GetParameter"
          Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/cid/${local.resource_prefix}*"
        }
      ]
    })
  }

  inline_policy {
    name = "Lambda"
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
    name = "S3-Access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Resource = "arn:aws:s3:::cid-data-${data.aws_caller_identity.current.account_id}/*"
        }
      ]
    })
  }
}

# Lambda Function
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "./scripts/account_collector.py"
  output_path = "./scripts/account_collector.zip"
}

resource "aws_lambda_function" "account_collector" {
  function_name = "${local.resource_prefix}account-collector-Lambda"
  description   = "Lambda function to retrieve the account list"
  runtime       = "python3.10"
  role          = aws_iam_role.lambda_role.arn
  handler       = "account_collector.lambda_handler"
  memory_size   = 2688
  timeout       = 600

  filename = "./scripts/account_collector.zip"

  environment {
    variables = {
      ROLE_NAME               = "CID-DC-Lambda-Assume-Role-Management-Account"
      MANAGEMENT_ACCOUNT_IDS  = var.management_account_id
      RESOURCE_PREFIX         = local.resource_prefix
      BUCKET_NAME             = "cid-data-${data.aws_caller_identity.current.account_id}"
      PREDEF_ACCOUNT_LIST_KEY = "account-list/account-list"
      LINKED_ACCOUNT_LIST_KEY = "account-list/linked-account-list.json"
      PAYER_ACCOUNT_LIST_KEY  = "account-list/payer-account-list.json"
    }
  }
}

output "lambda_function_name" {
  value = aws_lambda_function.account_collector.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.account_collector.arn
}


