locals {
  resource_prefix = "CID-DC-"
}

resource "aws_sfn_state_machine" "module_step_function" {
  name     = "${var.resource_prefix}${var.cid_data_name}-StateMachine"
  role_arn = var.step_function_execution_role_arn

  #! Direct definition of the state machine -- replace 
  definition = jsonencode({
    "Comment" = "A Hello World example of the Amazon States Language using a Pass state",
    "StartAt" = "HelloWorld",
    "States" = {
      "HelloWorld" = {
        "Type"   = "Pass",
        "Result" = "Hello, World!",
        "End"    = true
      }
    }
  })

  #   definition_substitutions = jsonencode({
  #     AccountCollectorLambdaARN = var.account_collector_lambda_arn
  #     ModuleLambdaARN           = aws_lambda_function.lambda_function.arn
  #     Crawlers                  = ["${var.resource_prefix}${var.cid_data_name}-Crawler"]
  #     CollectionType            = "LINKED"
  #     Params                    = ''
  #     Module                    = var.cid_data_name
  #     DeployRegion              = data.aws_region.current.name
  #     Account                   = data.aws_caller_identity.current.account_id
  #     Prefix                    = var.resource_prefix
  #   })
}

resource "aws_scheduler_schedule" "module_refresh_schedule" {
  name                = "${local.resource_prefix}${var.cid_data_name}-RefreshSchedule"
  description         = "Scheduler for the ODC ${var.cid_data_name} module"
  schedule_expression = var.schedule
  state               = "ENABLED"

  flexible_time_window {
    maximum_window_in_minutes = 30
    mode                      = "FLEXIBLE"
  }

  target {
    arn      = aws_sfn_state_machine.module_step_function.arn
    role_arn = var.scheduler_execution_role_arn
    input = jsonencode({
      module_lambda = aws_lambda_function.lambda_function.arn
      crawlers      = ["${local.resource_prefix}${var.cid_data_name}-Crawler"]
    })
  }
}

################ ALLOW STEP FUNCTION TO INVOKE LAMBDA ################ 
resource "aws_lambda_permission" "allow_step_function" {
  statement_id  = "AllowStepFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "states.amazonaws.com"
  source_arn    = aws_sfn_state_machine.module_step_function.arn
}


#################### SNS TOPICS AND SUBSCRIPTIONS ####################  
resource "aws_lambda_function_event_invoke_config" "event_invoke_config" {
  function_name = aws_lambda_function.lambda_function.function_name

  destination_config {
    on_success {
      destination = aws_sns_topic.success_topic.arn
    }
    on_failure {
      destination = aws_sns_topic.failure_topic.arn
    }
  }
}

resource "aws_sns_topic" "success_topic" {
  name = "${local.resource_prefix}${var.cid_data_name}-SuccessTopic"
}

resource "aws_sns_topic" "failure_topic" {
  name = "${local.resource_prefix}${var.cid_data_name}-FailureTopic"
}

resource "aws_sns_topic_subscription" "success_subscription" {
  topic_arn = aws_sns_topic.success_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lambda_function.arn
}

resource "aws_sns_topic_subscription" "failure_subscription" {
  topic_arn = aws_sns_topic.failure_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lambda_function.arn
}

variable "schedule" {
  description = "EventBridge Schedule to trigger the data collection"
  type        = string
  default     = "rate(14 days)"
}

