##############################
# BCM Data Exports (CUR 2.0) #
##############################

resource "aws_bcmdataexports_export" "cur2" {
  count = var.enable_cost_allocation_backfill ? 1 : 0

  export {
    name        = "blocks-cur-data-${var.customer_resource_id}"
    description = "CUR 2.0 export to S3 (Parquet), hourly with resource IDs"

    data_query {
      query_statement = file("${path.module}/cur_query.sql")

      table_configurations = {
        "COST_AND_USAGE_REPORT" = {
          INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY = "FALSE"
          TIME_GRANULARITY                      = "HOURLY"
          INCLUDE_RESOURCES                     = "TRUE"
          INCLUDE_SPLIT_COST_ALLOCATION_DATA    = "FALSE"
        }
      }
    }

    destination_configurations {
      s3_destination {
        s3_bucket = aws_s3_bucket.cur_bucket[0].id
        s3_prefix = "cur2"
        s3_region = local.region

        s3_output_configurations {
          compression = "PARQUET"
          format      = "PARQUET"
          output_type = "CUSTOM"
          overwrite   = "OVERWRITE_REPORT"
        }
      }
    }

    refresh_cadence {
      frequency = "SYNCHRONOUS"
    }
  }

  tags = local.common_tags

  depends_on = [aws_s3_bucket_policy.cur_bucket]
}
