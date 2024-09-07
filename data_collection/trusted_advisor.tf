resource "aws_iam_role" "lambda_role_trusted_advisor" {
  name = "${local.resource_prefix}trusted-advisor-LambdaRole"

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
    name = "AssumeMultiAccountRole"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "sts:AssumeRole"
          Resource = "arn:aws:iam::*:role/CID-DC-Optimization-Data-Multi-Account-Role"
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
            "s3:PutObject"
          ]
          Resource = "arn:aws:s3:::cid-data-${data.aws_caller_identity.current.account_id}/*"
        }
      ]
    })
  }
}

data "archive_file" "lambda-trusted-advisor" {
  type        = "zip"
  source_file = "./scripts/trust_advisor.py"
  output_path = "./scripts/trust_advisor.zip"
}


resource "aws_lambda_function" "lambda_function_trusted_advisor" {
  function_name = "${local.resource_prefix}trusted-advisor-Lambda"
  description   = "Lambda function to retrieve trusted advisor"
  runtime       = "python3.10"
  handler       = "trust_advisor.lambda_handler"
  filename      = "./scripts/trust_advisor.zip"
  role          = aws_iam_role.lambda_role_trusted_advisor.arn
  memory_size   = 2688
  timeout       = 300

  environment {
    variables = {
      BUCKET_NAME = "cid-data-${data.aws_caller_identity.current.account_id}"
      PREFIX      = "trusted-advisor"
      ROLENAME    = "CID-DC-Optimization-Data-Multi-Account-Role"
      COSTONLY    = "no"
    }
  }
}

resource "aws_cloudwatch_log_group" "log_group_trusted_advisor" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_function_trusted_advisor.function_name}"
  retention_in_days = 60
}

##################### GLUE CRAWLER #####################
resource "aws_glue_crawler" "crawler_trusted_advisor" {
  name          = "${local.resource_prefix}trusted-advisor-Crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = "optimization_data"

  s3_target {
    path = "s3://cid-data-${data.aws_caller_identity.current.account_id}/trusted-advisor/trusted-advisor-data/"
  }

  configuration = jsonencode({
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    Version = 1.0
  })
}

##################### STEP FUNCTION #####################
resource "aws_sfn_state_machine" "sfn_trusted_advisor" {
  name     = "CID-DC-trusted-advisor-StateMachine"
  role_arn = aws_iam_role.step_function_execution_role.arn
  definition = templatefile("./definitions/template.asl.json", {
    "account_id"  = data.aws_caller_identity.current.account_id
    "module_name" = "trusted-advisor"
    "type"        = "LINKED"
    "comment"     = "Orchestrate the collection of trusted-advisor data"
  })
}
