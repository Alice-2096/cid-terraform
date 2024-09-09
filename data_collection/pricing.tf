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

// Below, we define a total of 7 crawlers and step functions as part of the pricing data collection process 
##################### pricing-AWSComputeSavingsPlan #####################
resource "aws_glue_crawler" "crawler_pricing_AWSComputeSavingsPlan" {
  name          = "${local.resource_prefix}pricing-AWSComputeSavingsPlan-Crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = "optimization_data"

  s3_target {
    path = "s3://cid-data-${data.aws_caller_identity.current.account_id}/pricing/pricing-computesavingsplan-data/"
  }

  configuration = jsonencode({
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
      Tables = {
        AddOrUpdateBehavior = "MergeNewColumns"
      }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    Version = 1.0
  })

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }
}

resource "aws_sfn_state_machine" "sfn_pricing_AWSComputeSavingsPlan" {
  name     = "CID-DC-pricing-AWSComputeSavingsPlan-StateMachine"
  role_arn = aws_iam_role.step_function_execution_role.arn
  definition = templatefile("./definitions/pricing.asl.json", {
    "module_name" = "pricing-AWSComputeSavingsPlan"
    "path"        = "computesavingsplan"
    "service"     = "AWSComputeSavingsPlan"
  })
}

##################### pricing--AWSLambda #####################
resource "aws_glue_crawler" "crawler_pricing_AWSLambda" {
  name          = "${local.resource_prefix}pricing-AWSLambda-Crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = "optimization_data"

  s3_target {
    path = "s3://cid-data-${data.aws_caller_identity.current.account_id}/pricing/pricing-lambda-data/"
  }

  configuration = jsonencode({
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
      Tables = {
        AddOrUpdateBehavior = "MergeNewColumns"
      }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    Version = 1.0
  })

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }
}

resource "aws_sfn_state_machine" "sfn_pricing_AWSLambda" {
  name     = "CID-DC-pricing-AWSLambda-StateMachine"
  role_arn = aws_iam_role.step_function_execution_role.arn
  definition = templatefile("./definitions/pricing.asl.json", {
    "module_name" = "pricing-AWSLambda"
    "path"        = "lambda"
    "service"     = "AWSLambda"
  })
}

##################### pricing-AmazonEC2 #####################
resource "aws_glue_crawler" "crawler_pricing_AmazonEC2" {
  name          = "${local.resource_prefix}pricing-AmazonEC2-Crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = "optimization_data"

  s3_target {
    path = "s3://cid-data-${data.aws_caller_identity.current.account_id}/pricing/pricing-ec2-data/"
  }

  configuration = jsonencode({
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
      Tables = {
        AddOrUpdateBehavior = "MergeNewColumns"
      }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    Version = 1.0
  })

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }
}

resource "aws_sfn_state_machine" "sfn_pricing_AmazonEC2" {
  name     = "CID-DC-pricing-AmazonEC2-StateMachine"
  role_arn = aws_iam_role.step_function_execution_role.arn
  definition = templatefile("./definitions/pricing.asl.json", {
    "module_name" = "pricing-AmazonEC2"
    "path"        = "ec2"
    "service"     = "AmazonEC2"
  })
}

##################### pricing-AmazonES #####################
resource "aws_glue_crawler" "crawler_pricing_AmazonES" {
  name          = "${local.resource_prefix}pricing-AmazonES-Crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = "optimization_data"

  s3_target {
    path = "s3://cid-data-${data.aws_caller_identity.current.account_id}/pricing/pricing-opensearch-data/"
  }

  configuration = jsonencode({
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
      Tables = {
        AddOrUpdateBehavior = "MergeNewColumns"
      }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    Version = 1.0
  })

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }
}

resource "aws_sfn_state_machine" "sfn_pricing_AmazonES" {
  name     = "CID-DC-pricing-AmazonES-StateMachine"
  role_arn = aws_iam_role.step_function_execution_role.arn
  definition = templatefile("./definitions/pricing.asl.json", {
    "module_name" = "pricing-AmazonES"
    "path"        = "opensearch"
    "service"     = "AmazonES"
  })
}

##################### pricing-AmazonElastiCache #####################
resource "aws_glue_crawler" "crawler_pricing_AmazonElastiCache" {
  name          = "${local.resource_prefix}pricing-AmazonElastiCache-Crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = "optimization_data"

  s3_target {
    path = "s3://cid-data-${data.aws_caller_identity.current.account_id}/pricing/pricing-elasticache-data/"
  }

  configuration = jsonencode({
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
      Tables = {
        AddOrUpdateBehavior = "MergeNewColumns"
      }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    Version = 1.0
  })

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }
}

resource "aws_sfn_state_machine" "sfn_pricing_AmazonElastiCache" {
  name     = "CID-DC-pricing-AmazonElastiCache-StateMachine"
  role_arn = aws_iam_role.step_function_execution_role.arn
  definition = templatefile("./definitions/pricing.asl.json", {
    "module_name" = "pricing-AmazonElastiCache"
    "path"        = "elasticache"
    "service"     = "AmazonElastiCache"
  })
}

##################### pricing-AmazonRDS #####################
resource "aws_glue_crawler" "crawler_pricing_AmazonRDS" {
  name          = "${local.resource_prefix}pricing-AmazonRDS-Crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = "optimization_data"

  s3_target {
    path = "s3://cid-data-${data.aws_caller_identity.current.account_id}/pricing/pricing-rds-data/"
  }

  configuration = jsonencode({
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
      Tables = {
        AddOrUpdateBehavior = "MergeNewColumns"
      }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    Version = 1.0
  })

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }
}

resource "aws_sfn_state_machine" "sfn_pricing_AmazonRDS" {
  name     = "CID-DC-pricing-AmazonRDS-StateMachine"
  role_arn = aws_iam_role.step_function_execution_role.arn
  definition = templatefile("./definitions/pricing.asl.json", {
    "module_name" = "pricing-AmazonRDS"
    "path"        = "rds"
    "service"     = "AmazonRDS"
  })
}

##################### pricing-RegionNames #####################
resource "aws_glue_crawler" "crawler_pricing_RegionNames" {
  name          = "${local.resource_prefix}pricing-RegionNames-Crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = "optimization_data"

  s3_target {
    path = "s3://cid-data-${data.aws_caller_identity.current.account_id}/pricing/pricing-regionnames-data/"
  }

  configuration = jsonencode({
    CrawlerOutput = {
      Partitions = {
        AddOrUpdateBehavior = "InheritFromTable"
      }
      Tables = {
        AddOrUpdateBehavior = "MergeNewColumns"
      }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    Version = 1.0
  })

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }
}

resource "aws_sfn_state_machine" "sfn_pricing_RegionNames" {
  name     = "CID-DC-pricing-RegionNames-StateMachine"
  role_arn = aws_iam_role.step_function_execution_role.arn
  definition = templatefile("./definitions/pricing.asl.json", {
    "module_name" = "pricing-RegionNames"
    "path"        = "regionnames"
    "service"     = "RegionNames"
  })
}

##################### Schedulers ##################### 
#TODO - Add scheduler for each crawler

##################### GLUE TABLES #####################
resource "aws_glue_catalog_table" "pricing" {
  for_each      = local.ServicesMapPricing
  depends_on    = [aws_glue_catalog_database.glue_database]
  database_name = "optimization_data"
  name          = "pricing_${each.value.path}_data"

  table_type = "EXTERNAL_TABLE"
  parameters = {
    "classification"  = "csv"
    "compressionType" = "none"
  }

  storage_descriptor {
    number_of_buckets = -1
    dynamic "columns" {
      for_each = each.value.fields

      content {
        name = columns.value.Name
        type = columns.value.Type
      }
    }
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    location      = "s3://cid-data-${data.aws_caller_identity.current.account_id}/pricing/pricing-${each.value.path}-data/"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
      parameters = {
        "separatorChar"        = ","
        "quoteChar"            = "\""
        "serialization.format" = "1"
      }
    }
  }
  dynamic "partition_keys" {
    for_each = each.value.partition

    content {
      name = partition_keys.value.Name
      type = partition_keys.value.Type
    }
  }

}
