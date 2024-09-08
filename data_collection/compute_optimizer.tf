resource "aws_iam_role" "lambda_role_compute_optimizer" {
  name = "${local.resource_prefix}compute-optimizer-LambdaRole"

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
    name = "compute-optimizer-ManagementAccount-LambdaRole"
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
}

data "archive_file" "lambda-compute-optimizer" {
  type        = "zip"
  source_file = "./scripts/compute_optimizer.py"
  output_path = "./scripts/compute_optimizer.zip"
}

resource "aws_lambda_function" "lambda_function_compute_optimizer" {
  function_name = "${local.resource_prefix}compute-optimizer-Lambda"
  description   = "LambdaFunction to start ComputeOptimizer export jobs"
  runtime       = "python3.10"
  handler       = "compute_optimizer.lambda_handler"
  filename      = "./scripts/compute_optimizer.zip"
  role          = aws_iam_role.lambda_role_compute_optimizer.arn
  memory_size   = 2688
  timeout       = 300

  environment {
    variables = {
      BUCKET_PREFIX           = "cid-data-${data.aws_caller_identity.current.account_id}"
      INCLUDE_MEMBER_ACCOUNTS = "yes"
      MANAGEMENT_ACCOUNT_IDS  = var.management_account_id
      ROLE_NAME               = "CID-DC-Lambda-Assume-Role-Management-Account"
      REGIONS                 = var.enabled_regions
    }
  }
}

resource "aws_cloudwatch_log_group" "log_group_compute_optimizer" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_function_compute_optimizer.function_name}"
  retention_in_days = 60
}

##################### STEP FUNCTION #####################
resource "aws_sfn_state_machine" "sfn_compute_optimizer" {
  name     = "CID-DC-compute-optimizer-StateMachine"
  role_arn = aws_iam_role.step_function_execution_role.arn
  definition = templatefile("./definitions/template.asl.json", {
    "account_id"  = data.aws_caller_identity.current.account_id
    "module_name" = "compute-optimizer"
    "type"        = "Payers"
    "crawler"     = "CID-DC-compute-optimizer-Crawler"
    "params"      = ""
  })
}

####################### SCHEDULER #####################
resource "aws_scheduler_schedule" "schedule_compute_optimizer" {
  description         = "Scheduler for the ODC compute-optimizer module"
  name                = "${local.resource_prefix}compute-optimizer-RefreshSchedule"
  group_name          = "default"
  schedule_expression = "rate(14 days)"
  state               = "ENABLED"

  flexible_time_window {
    mode                      = "FLEXIBLE"
    maximum_window_in_minutes = 30
  }

  target {
    arn      = aws_sfn_state_machine.sfn_compute_optimizer.arn
    role_arn = aws_iam_role.scheduler_execution_role.arn
  }
}
