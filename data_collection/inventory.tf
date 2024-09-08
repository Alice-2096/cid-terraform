resource "aws_iam_role" "lambda_role_inventory" {
  name = "${local.resource_prefix}inventory-LambdaRole"

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

data "archive_file" "lambda-inventory" {
  type        = "zip"
  source_file = "./scripts/inventory.py"
  output_path = "./scripts/inventory.zip"
}

resource "aws_lambda_function" "lambda_function_inventory" {
  function_name = "${local.resource_prefix}inventory-Lambda"
  description   = "Lambda function to retrieve inventory"
  runtime       = "python3.10"
  handler       = "inventory.lambda_handler"
  filename      = "./scripts/inventory.zip"
  role          = aws_iam_role.lambda_role_inventory.arn
  memory_size   = 2688
  timeout       = 300

  environment {
    variables = {
      BUCKET_NAME = "cid-data-${data.aws_caller_identity.current.account_id}"
      PREFIX      = "inventory"
      ROLENAME    = "CID-DC-Optimization-Data-Multi-Account-Role"
      REGIONS     = var.enabled_regions
    }
  }
}

resource "aws_cloudwatch_log_group" "log_group_inventory" {
  name              = "/aws/lambda/${aws_lambda_function.lambda_function_inventory.function_name}"
  retention_in_days = 60
}

##################### GLUE CRAWLER #####################
locals {
  inventory_map = {
    AMI                 = "inventory-ami-data/"
    Ec2Instances        = "inventory-ec2-instances-data/"
    ElasticacheClusters = "inventory-elasticache-clusters-data/"
    LambdaFunctions     = "inventory-lambda-functions-data/"
    OpensearchDomains   = "inventory-opensearch-domains-data/"
    RdsDbClusters       = "inventory-rds-db-clusters-data/"
    RdsDbInstances      = "inventory-rds-db-instances-data/"
    RdsDbSnapshots      = "inventory-rds-db-snapshots-data/"
    VpcInstances        = "inventory-vpc-data/"
    EKSClusters         = "inventory-eks-data/"
    EBS                 = "inventory-ebs-data/"
    Snapshot            = "inventory-snapshot-data/"
  }
}

resource "aws_glue_crawler" "crawler_inventory" {
  for_each = local.inventory_map

  name          = "${local.resource_prefix}inventory-${each.key}-Crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = "optimization_data"

  s3_target {
    path = "s3://cid-data-${data.aws_caller_identity.current.account_id}/inventory/${each.value}"
  }

  configuration = jsonencode({
    CrawlerOutput = {
      Tables = {
        TableThreshold = 1
      }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    Version = 1.0
  })
}

##################### STEP FUNCTION #####################
# resource "aws_sfn_state_machine" "sfn_inventory" {
#   name     = "CID-DC-inventory-StateMachine"
#   role_arn = aws_iam_role.step_function_execution_role.arn
#   definition = templatefile("./definitions/template.asl.json", {
#     "account_id"  = data.aws_caller_identity.current.account_id
#     "module_name" = "inventory"
#     "type"        = "Payers"
#     "comment"     = "Orchestrate the collection of inventory data"
#   })
# }
