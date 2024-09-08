# Glue database 
resource "aws_glue_catalog_database" "glue_database" {
  name = "optimization_data"
}

# Glue catalog tables for cost anomaly data and inventory data 
resource "aws_glue_catalog_table" "cost_anomaly_data" {
  depends_on    = [aws_glue_catalog_database.glue_database]
  database_name = "optimization_data"
  name          = "cost_anomaly_data"

  table_type = "EXTERNAL_TABLE"
  parameters = {
    "classification"  = "json"
    "compressionType" = "none"
  }

  storage_descriptor {
    number_of_buckets = -1
    columns {
      name = "anomalyid"
      type = "string"
    }
    columns {
      name = "anomalystartdate"
      type = "string"
    }
    columns {
      name = "anomalyenddate"
      type = "string"
    }
    columns {
      name = "dimensionvalue"
      type = "string"
    }
    columns {
      name = "maximpact"
      type = "double"
    }
    columns {
      name = "totalactualspend"
      type = "double"
    }
    columns {
      name = "totalexpectedspend"
      type = "double"
    }
    columns {
      name = "totalimpact"
      type = "double"
    }
    columns {
      name = "totalimpactpercentage"
      type = "double"
    }
    columns {
      name = "monitorarn"
      type = "string"
    }
    columns {
      name = "linkedaccount"
      type = "string"
    }
    columns {
      name = "linkedaccountname"
      type = "string"
    }
    columns {
      name = "region"
      type = "string"
    }
    columns {
      name = "service"
      type = "string"
    }
    columns {
      name = "usagetype"
      type = "string"
    }

    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    location      = "s3://cid-data-${data.aws_caller_identity.current.account_id}/cost-anomaly/cost-anomaly-data/"

    ser_de_info {
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        paths = "AnomalyEndDate,AnomalyId,AnomalyStartDate,DimensionValue,LinkedAccount,LinkedAccountName,MaxImpact,MonitorArn,Region,Service,TotalActualSpend,TotalExpectedSpend,TotalImpact,TotalImpactpercentage,UsageType"
      }
    }
  }

  partition_keys {
    name = "payer_id"
    type = "string"
  }
  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
  }
  partition_keys {
    name = "day"
    type = "string"
  }
}


