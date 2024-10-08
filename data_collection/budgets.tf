##################### LAMBDA FUNCTION #####################
resource "aws_iam_role" "lambda_role_budgets" {
  name = "${local.resource_prefix}budgets-LambdaRole"

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
    name = "budgets-MultiAccount-LambdaRole"
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
          Resource = ["arn:aws:s3:::cid-data-${data.aws_caller_identity.current.account_id}/*"]
        }
      ]
    })
  }
}

data "archive_file" "lambda-budgets" {
  type        = "zip"
  source_file = "./scripts/budgets.py"
  output_path = "./scripts/budgets.zip"
}


resource "aws_lambda_function" "lambda_function_budgets" {
  function_name = "${local.resource_prefix}budgets-Lambda"
  description   = "Lambda function to retrieve budgets data"
  runtime       = "python3.12"
  handler       = "budgets.lambda_handler"
  filename      = "./scripts/budgets.zip"
  role          = aws_iam_role.lambda_role_budgets.arn
  memory_size   = 2688
  timeout       = 300

  environment {
    variables = {
      BUCKET_NAME = "cid-data-${data.aws_caller_identity.current.account_id}"
      PREFIX      = "budgets"
      ROLE_NAME   = "CID-DC-Optimization-Data-Multi-Account-Role"
    }
  }
}

resource "aws_cloudwatch_log_group" "log_group_budgets" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_function_budgets.function_name}"
  retention_in_days = 60
}


##################### GLUE CRAWLER #####################
resource "aws_glue_crawler" "crawler_budgets" {
  name          = "${local.resource_prefix}budgets-Crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = "optimization_data"

  s3_target {
    path = "s3://cid-data-${data.aws_caller_identity.current.account_id}/budgets/budgets-data/"
  }
}

##################### STEP FUNCTION #####################
resource "aws_sfn_state_machine" "sfn_budgets" {
  name     = "CID-DC-budgets-StateMachine"
  role_arn = aws_iam_role.step_function_execution_role.arn
  definition = templatefile("./definitions/template.asl.json", {
    "account_id"  = data.aws_caller_identity.current.account_id
    "module_name" = "budgets"
    "type"        = "LINKED"
    "comment"     = "Orchestrate the collection of cost-anomaly data"
    "crawler"     = "CID-DC-budgets-Crawler"
    "params"      = ""
  })
}

####################### SCHEDULER #####################
resource "aws_scheduler_schedule" "schedule_budgets" {
  description         = "Scheduler for the ODC budgets module"
  name                = "${local.resource_prefix}budgets-RefreshSchedule"
  group_name          = "default"
  schedule_expression = "rate(1 day)"
  state               = "ENABLED"

  flexible_time_window {
    mode                      = "FLEXIBLE"
    maximum_window_in_minutes = 30
  }
  target {
    arn      = aws_sfn_state_machine.sfn_budgets.arn
    role_arn = aws_iam_role.scheduler_execution_role.arn
  }
}

####################### ATHENA VIEW #######################
resource "aws_athena_named_query" "athena_query_budgets" {
  name        = "budgets_view"
  database    = "optimization_data"
  description = "Provides a summary view of ${local.resource_prefix}"

  query = <<EOF
CREATE OR REPLACE VIEW budgets_view AS
SELECT
  budgetname AS budget_name,
  CAST(budgetlimit.amount AS decimal) AS budget_amount,
  CAST(calculatedspend.actualspend.amount AS decimal) AS actualspend,
  CAST(calculatedspend.forecastedspend.amount AS decimal) AS forecastedspend,
  timeunit,
  budgettype AS budget_type,
  account_id,
  timeperiod.start AS start_date,
  timeperiod."end" AS end_date,
  year AS budget_year,
  month AS budget_month
FROM
  optimization_data.budgets_data
WHERE (budgettype = 'COST') AND costfilters.filter[1] = 'None'
EOF
}
