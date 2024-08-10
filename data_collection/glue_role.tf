# IAM Role for AWS Glue
resource "aws_iam_role" "glue_role" {
  name = "${var.resource_prefix}Glue-Crawler"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach S3 Read Policy
resource "aws_iam_role_policy" "s3_read_policy" {
  name   = "S3Read"
  role   = aws_iam_role.glue_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = "arn:${data.aws_partition.partition}:s3:::${var.destination_bucket}"
      },
      {
        Effect = "Allow"
        Action = "s3:GetObject"
        Resource = "arn:${data.aws_partition.partition}:s3:::${var.destination_bucket}/*"
      }
      # Uncomment and configure if bucket is encrypted by Custom KMS Key
      # {
      #   Effect = "Allow"
      #   Action = "kms:Decrypt"
      #   Resource = "arn:${data.aws_partition.partition}:kms:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:key/key-id"
      # }
    ]
  })
}

# Attach Glue Policy
resource "aws_iam_role_policy" "glue_policy" {
  name   = "Glue"
  role   = aws_iam_role.glue_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:UpdateTable",
          "glue:GetTableVersion",
          "glue:GetTableVersions",
          "glue:DeleteTableVersion",
          "glue:CreatePartition",
          "glue:BatchCreatePartition",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:BatchGetPartition",
          "glue:UpdatePartition",
          "glue:DeletePartition",
          "glue:TagResource"
        ]
        Resource = [
          "arn:${data.aws_partition.partition}:glue:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:${data.aws_partition.partition}:glue:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:database/${var.database_name}",
          "arn:${data.aws_partition.partition}:glue:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:table/${var.database_name}/*"
        ]
      }
    ]
  })
}

# Attach CloudWatch Policy
resource "aws_iam_role_policy" "cloudwatch_policy" {
  name   = "CloudWatch"
  role   = aws_iam_role.glue_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:${data.aws_partition.partition}:logs:*:*:/aws-glue/*"
      }
    ]
  })
}

# Data source for AWS partition
data "aws_partition" "partition" {}

# Data source for AWS region
data "aws_region" "region" {}

# Data source for AWS caller identity
data "aws_caller_identity" "current" {}

# Variables definition
variable "resource_prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "destination_bucket" {
  description = "Name of the S3 Bucket"
  type        = string
}

variable "database_name" {
  description = "Name of the Glue database"
  type        = string
}
