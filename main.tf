provider "aws" {
  region = "us-east-1" 
}

locals {
  resource_prefix = "CID-DC-"  
}

resource "aws_iam_role" "lambda_role" {
  name               = "${local.resource_prefix}Optimization-Data-Multi-Account-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRole",
      Principal = {
        AWS = "arn:aws:iam::${var.data_collection_account_id}:root"
      },
      Condition = {
        ArnEquals = {
          "aws:PrincipalArn" = [
            "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}budgets-LambdaRole",
            "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}ecs-chargeback-LambdaRole",
            "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}inventory-LambdaRole",
            "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}rds-usage-LambdaRole",
            "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}transit-gateway-LambdaRole",
            "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}trusted-advisor-LambdaRole"
          ]
        }
      }
    }]
  })
}

resource "aws_iam_policy" "ta_policy" {
  count = var.include_ta_module == "yes" ? 1 : 0

  name        = "TAPolicy"
  description = "Policy for Trusted Advisor data collection"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "support:DescribeTrustedAdvisorChecks",
        "support:DescribeTrustedAdvisorCheckResult"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_policy" "budgets_read_only_policy" {
  count = var.include_budgets_module == "yes" ? 1 : 0

  name        = "BudgetsReadOnlyPolicy"
  description = "Policy for Budgets data collection"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "budgets:ViewBudget",
        "budgets:DescribeBudgets",
        "budgets:ListTagsForResource"
      ],
      Resource = "arn:aws:budgets::*:budget/*"
    }]
  })
}

resource "aws_iam_policy" "inventory_collector_policy" {
  count = var.include_inventory_collector_module == "yes" ? 1 : 0

  name        = "InventoryCollectorPolicy"
  description = "Policy for Inventory Collector data collection"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "ec2:DescribeImages",
        "ec2:DescribeVolumes",
        "ec2:DescribeSnapshots",
        "ec2:DescribeRegions",
        "ec2:DescribeInstances",
        "ec2:DescribeVpcs",
        "rds:DescribeDBClusters",
        "rds:DescribeDBInstances",
        "rds:DescribeDBSnapshots",
        "es:ListDomainNames",
        "es:DescribeDomain",
        "es:DescribeElasticsearchDomains",
        "elasticache:DescribeCacheClusters",
        "eks:ListClusters",
        "eks:DescribeCluster",
        "lambda:ListFunctions"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_policy" "ecs_chargeback_policy" {
  count = var.include_ecs_chargeback_module == "yes" ? 1 : 0

  name        = "ECSChargebackPolicy"
  description = "Policy for ECS Chargeback data collection"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "ecs:ListServices",
        "ecs:DescribeServices",
        "ecs:ListClusters",
        "ec2:DescribeRegions"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_policy" "rds_utilization_policy" {
  count = var.include_rds_utilization_module == "yes" ? 1 : 0

  name        = "RDSUtilizationPolicy"
  description = "Policy for RDS Utilization data collection"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "rds:DescribeDBInstances",
        "ec2:DescribeRegions",
        "cloudwatch:GetMetricStatistics"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_policy" "transit_gateway_policy" {
  count = var.include_transit_gateway_module == "yes" ? 1 : 0

  name        = "TransitGatewayPolicy"
  description = "Policy for Transit Gateway data collection"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "ec2:DescribeTransitGatewayAttachments",
        "cloudwatch:Describe*",
        "cloudwatch:Get*",
        "cloudwatch:List*"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ta_policy_attachment" {
  count      = var.include_ta_module == "yes" ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.ta_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "budgets_read_only_policy_attachment" {
  count      = var.include_budgets_module == "yes" ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.budgets_read_only_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "inventory_collector_policy_attachment" {
  count      = var.include_inventory_collector_module == "yes" ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.inventory_collector_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "ecs_chargeback_policy_attachment" {
  count      = var.include_ecs_chargeback_module == "yes" ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.ecs_chargeback_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "rds_utilization_policy_attachment" {
  count      = var.include_rds_utilization_module == "yes" ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.rds_utilization_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "transit_gateway_policy_attachment" {
  count      = var.include_transit_gateway_module == "yes" ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.transit_gateway_policy[0].arn
}

