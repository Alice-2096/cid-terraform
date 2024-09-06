# IAM Role for AWS Glue
resource "aws_iam_role" "glue_role" {
  name = "CID-DC-Glue-Crawler"
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
  name = "S3Read"
  role = aws_iam_role.glue_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${var.destination_bucket}"
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.destination_bucket}/*"
      }
    ]
  })
}

# Attach Glue Policy
resource "aws_iam_role_policy" "glue_policy" {
  name = "Glue"
  role = aws_iam_role.glue_role.id
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
          "arn:aws:glue:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:database/${var.database_name}",
          "arn:aws:glue:${data.aws_region.region}:${data.aws_caller_identity.current.account_id}:table/${var.database_name}/*"
        ]
      }
    ]
  })
}

# Attach CloudWatch Policy
resource "aws_iam_role_policy" "cloudwatch_policy" {
  name = "CloudWatch"
  role = aws_iam_role.glue_role.id
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
        Resource = "arn:aws:logs:*:*:/aws-glue/*"
      }
    ]
  })
}


variable "destination_bucket" {
  description = "Name of the S3 Bucket"
  type        = string
}

variable "database_name" {
  description = "Name of the Glue database"
  type        = string
}
