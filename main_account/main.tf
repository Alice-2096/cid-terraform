provider "aws" {
  region = "us-east-1"
}

locals {
  resource_prefix = "CID-DC-"
}

resource "aws_iam_role" "lambda_role" {
  name = "${local.resource_prefix}Lambda-Assume-Role-Management-Account"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.data_collection_account_id}:root"
        }
        Condition = {
          "ForAnyValue:ArnEquals" = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}account-collector-LambdaRole",
              "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}organizations-LambdaRole",
              "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}compute-optimizer-LambdaRole",
              "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}cost-anomaly-LambdaRole",
              "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}cost-explorer-rightsizing-LambdaRole",
              "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}cost-optimization-hub-LambdaRole",
              "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}backup-LambdaRole",
              "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}health-events-LambdaRole",
              "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}license-manager-LambdaRole",
              "arn:aws:iam::${var.data_collection_account_id}:role/${local.resource_prefix}RLS-LambdaRole"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "aws_organization_policy" {
  name = "Management-Account-permissions"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "organizations:ListAccountsForParent",
          "organizations:DescribeAccount",
          "organizations:ListParents",
          "organizations:ListRoots",
          "organizations:ListChildren",
          "organizations:ListTagsForResource",
          "organizations:ListAccounts",
          "organizations:DescribeOrganizationalUnit",
          "organizations:ListCreateAccountStatus",
          "organizations:DescribeOrganization",
          "organizations:ListOrganizationalUnitsForParent"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "rightsizing_recommendations_policy" {
  count = var.include_rightsizing_module ? 1 : 0
  name  = "RightsizingRecommendationsPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ce:GetRightsizingRecommendation"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "cost_anomalies_policy" {
  count = var.include_cost_anomaly_module ? 1 : 0
  name  = "CostAnomaliesPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ce:GetAnomalies"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "backup_policy" {
  count = var.include_backup_module ? 1 : 0
  name  = "BackupEventsPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "backup:DescribeBackupJob",
          "backup:DescribeCopyJob",
          "backup:DescribeRestoreJob",
          "backup:ListBackupJobs",
          "backup:ListCopyJobs",
          "backup:ListRestoreJobs"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "compute_optimizer_policy" {
  count = var.include_compute_optimizer_module ? 1 : 0
  name  = "ComputeOptimizer-ExportRecommendations"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "compute-optimizer:ExportLambdaFunctionRecommendations",
          "compute-optimizer:GetLambdaFunctionRecommendations",
          "lambda:ListFunctions",
          "lambda:ListProvisionedConcurrencyConfigs"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "compute-optimizer:ExportAutoScalingGroupRecommendations",
          "compute-optimizer:GetAutoScalingGroupRecommendations",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "compute-optimizer:ExportEBSVolumeRecommendations",
          "compute-optimizer:GetEBSVolumeRecommendations",
          "ec2:DescribeVolumes"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "compute-optimizer:ExportEC2InstanceRecommendations",
          "compute-optimizer:GetEC2InstanceRecommendations",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "compute-optimizer:ExportECSServiceRecommendations",
          "compute-optimizer:GetECSServiceRecommendations",
          "compute-optimizer:GetECSServiceRecommendationProjectedMetrics",
          "ecs:ListServices",
          "ecs:ListClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "compute-optimizer:ExportLicenseRecommendations",
          "compute-optimizer:GetLicenseRecommendations",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "compute-optimizer:ExportRDSDatabaseRecommendations",
          "compute-optimizer:GetRDSDatabaseRecommendations",
          "compute-optimizer:GetRDSDatabaseRecommendationProjectedMetrics",
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "cost_optimization_hub_policy" {
  count = var.include_cost_optimization_hub_module ? 1 : 0
  name  = "CostOptimizationHubRecommendations"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cost-optimization-hub:ListEnrollmentStatuses",
          "cost-optimization-hub:GetPreferences",
          "cost-optimization-hub:GetRecommendation",
          "cost-optimization-hub:ListRecommendations",
          "cost-optimization-hub:ListRecommendationSummaries",
          "organizations:DescribeOrganization",
          "organizations:ListAccounts",
          "organizations:ListAWSServiceAccessForOrganization",
          "organizations:ListParents",
          "organizations:DescribeOrganizationalUnit",
          "ce:ListCostAllocationTags",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "health_events_policy" {
  count = var.include_health_events_module ? 1 : 0
  name  = "HealthEventsPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "health:DescribeEventsForOrganization",
          "health:DescribeEventDetailsForOrganization",
          "health:DescribeAffectedAccountsForOrganization",
          "health:DescribeAffectedEntitiesForOrganization"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "license_manager_policy" {
  count = var.include_license_manager_module ? 1 : 0
  name  = "LicenseManagerPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "license-manager:ListReceivedGrants",
          "license-manager:ListReceivedLicenses",
          "license-manager:ListReceivedGrantsForOrganization"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_organization_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.aws_organization_policy.arn
}

resource "aws_iam_role_policy_attachment" "rightsizing_recommendations_policy_attachment" {
  count      = var.include_rightsizing_module ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.rightsizing_recommendations_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "cost_anomalies_policy_attachment" {
  count      = var.include_cost_anomaly_module ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.cost_anomalies_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "backup_policy_attachment" {
  count      = var.include_backup_module ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.backup_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "compute_optimizer_policy_attachment" {
  count      = var.include_compute_optimizer_module ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.compute_optimizer_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "cost_optimization_hub_policy_attachment" {
  count      = var.include_cost_optimization_hub_module ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.cost_optimization_hub_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "health_events_policy_attachment" {
  count      = var.include_health_events_module ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.health_events_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "license_manager_policy_attachment" {
  count      = var.include_license_manager_module ? 1 : 0
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.license_manager_policy[0].arn
}

