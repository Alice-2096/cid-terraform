# IAM Role for the glue crawler to access S3 and create tables in Glue
resource "aws_iam_role" "glue_role" {
  name = "CID-DC-Glue-Crawler"

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

  inline_policy {
    name = "S3Read"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "s3:ListBucket"
          Resource = ["arn:aws:s3:::cid-data-${data.aws_caller_identity.current.account_id}"]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject"
          ]
          Resource = ["arn:aws:s3:::cid-data-${data.aws_caller_identity.current.account_id}/*"]
        }
      ]
    })
  }

  inline_policy {
    name = "Glue"
    policy = jsonencode({
      "Version" = "2012-10-17",
      Statement = [
        {
          "Action" : [
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
          ],
          "Resource" : [
            "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:catalog",
            "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:database/optimization_data",
            "arn:aws:glue:us-east-1:${data.aws_caller_identity.current.account_id}:table/optimization_data/*"
          ],
          "Effect" : "Allow"
        }
      ]
    })

  }
  inline_policy {
    name = "CloudWatch"
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
}
