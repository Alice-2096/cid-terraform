resource "aws_iam_role" "lambda_role_organizations" {
  name = "${local.resource_prefix}organizations-LambdaRole"

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
    name = "organizations-ManagementAccount-LambdaRole"
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
    name = "S3-Access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:PutObject"
          ]
          Resource = "arn:aws:s3:::cid-data-${data.aws_caller_identity.current.account_id}/*"
        }
      ]
    })
  }
}

data "archive_file" "lambda-organizations" {
  type        = "zip"
  source_file = "./scripts/organizations.py"
  output_path = "./scripts/organizations.zip"
}


resource "aws_lambda_function" "lambda_function_organizations" {
  function_name = "${local.resource_prefix}organizations-Lambda"
  description   = "Lambda function to retrieve organizations"
  runtime       = "python3.10"
  handler       = "organizations.lambda_handler"
  filename      = "./scripts/organizations.zip"
  role          = aws_iam_role.lambda_role_organizations.arn
  memory_size   = 2688
  timeout       = 600

  environment {
    variables = {
      BUCKET_NAME = "cid-data-${data.aws_caller_identity.current.account_id}"
      PREFIX      = "organizations"
      ROLENAME    = "CID-DC-Lambda-Assume-Role-Management-Account"
    }
  }
}

resource "aws_cloudwatch_log_group" "log_group_organizations" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_function_organizations.function_name}"
  retention_in_days = 60
}

##################### GLUE CRAWLER #####################
resource "aws_glue_crawler" "crawler_organizations" {
  name          = "${local.resource_prefix}organizations-Crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = "optimization_data"

  s3_target {
    path = "s3://cid-data-${data.aws_caller_identity.current.account_id}/organizations/organization-data/"
  }
}

##################### STEP FUNCTION #####################
resource "aws_sfn_state_machine" "sfn_organizations" {
  name     = "CID-DC-organizations-StateMachine"
  role_arn = aws_iam_role.step_function_execution_role.arn
  definition = templatefile("./definitions/template.asl.json", {
    "account_id"  = data.aws_caller_identity.current.account_id
    "module_name" = "organizations"
    "type"        = "Payers"
    "crawler"     = "CID-DC-organizations-Crawler"
    "params"      = ""
  })
}
