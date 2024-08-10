################ LAMBDA ################
resource "aws_iam_role" "lambda_role" {
  name = "${var.resource_prefix}${var.cid_data_name}-LambdaRole"

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
          Effect = "Allow"
          Action = "sts:AssumeRole"
          Resource = "arn:aws:iam::*:role/${var.multi_account_role_name}"
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
          Resource = "${var.destination_bucket_arn}/*"
        }
      ]
    })
  }
}

resource "aws_lambda_function" "lambda_function" {
  function_name = "${var.resource_prefix}${var.cid_data_name}-Lambda"
  description    = "Lambda function to retrieve ${var.cid_data_name}"
  runtime        = "python3.10"
  memory_size    = 2688
  timeout        = 300
  role           = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      BUCKET_NAME = var.destination_bucket
      PREFIX      = var.cid_data_name
      ROLENAME    = var.multi_account_role_name
      COSTONLY    = "no"
    }
  }

}

resource "aws_logs_log_group" "log_group" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_function.function_name}"
  retention_in_days  = 60
}


################ CRAWLER ################
resource "aws_glue_crawler" "crawler" {
  name             = "${var.resource_prefix}${var.cid_data_name}-Crawler"
  role             = var.glue_role_arn
  database_name    = var.database_name

  s3_target {
    path = "s3://${var.destination_bucket}/${var.cid_data_name}/${var.cid_data_name}-data/"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })
}

