# athena.tf

# 建立 Glue Catalog Database
resource "aws_glue_catalog_database" "nginx_db" {
  name = "${var.project_name}_db"
}

# 建立 Athena External Table
resource "aws_glue_catalog_table" "nginx_logs_table" {
  name          = "nginx_logs"
  database_name = aws_glue_catalog_database.nginx_db.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    "EXTERNAL"                           = "TRUE"
    "has_encrypted_data"                 = "false"
    "input.regex"                        = "^([^ ]+) - ([^ ]+) \\[(.*?)\\] \"(.*?)\" (\\d{3}) (\\d+|-) \"([^\"]*)\" \"([^\"]*)\"$"
    "projection.enabled"                 = "true"
    "projection.year.type"               = "integer"
    "projection.year.range"              = "2024,2099"
    "projection.month.type"              = "integer"
    "projection.month.range"             = "01,12"
    "projection.day.type"                = "integer"
    "projection.day.range"               = "01,31"
    "projection.hour.type"               = "integer"
    "projection.hour.range"              = "00,23"
    "storage.location.template"          = "s3://${aws_s3_bucket.log_bucket.id}/nginx/year=$${year}/month=$${month}/day=$${day}/hour=$${hour}/"
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
  partition_keys {
    name = "hour"
    type = "string"
  }

  storage_descriptor {
    location = "s3://${aws_s3_bucket.log_bucket.id}/nginx/"
    input_format = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    
    ser_de_info {
      name                  = "RegexSerDe"
      serialization_library = "org.apache.hadoop.hive.serde2.RegexSerDe"
    }

    columns {
      name = "client_ip"
      type = "string"
    }
    columns {
      name = "identity"
      type = "string"
    }
    columns {
      name = "user"
      type = "string"
    }
    columns {
      name = "timestamp"
      type = "string"
    }
    columns {
      name = "request"
      type = "string"
    }
    columns {
      name = "status_code"
      type = "int"
    }
    columns {
      name = "bytes_sent"
      type = "bigint"
    }
    columns {
      name = "referer"
      type = "string"
    }
    columns {
      name = "user_agent"
      type = "string"
    }
  }
}
