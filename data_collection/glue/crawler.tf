
################ CRAWLER ################
resource "aws_glue_crawler" "crawler" {
  name          = "${local.resource_prefix}${var.cid_data_name}-Crawler"
  role          = var.glue_role_arn
  database_name = var.database_name

  s3_target {
    path = "s3://cid-data-${data.aws_caller_identity.current.account_id}/${var.cid_data_name}/${var.cid_data_name}-data/"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })
}

