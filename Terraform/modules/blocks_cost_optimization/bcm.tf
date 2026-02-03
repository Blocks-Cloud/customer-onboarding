##############################
# BCM Data Exports (CUR 2.0) #
##############################

resource "aws_bcmdataexports_export" "cur2" {
  export {
    name        = "blocks-cur-data-${var.customer_id}"
    description = "CUR 2.0 export - Hourly granularity with resource IDs for Blocks.cloud cost optimization"

    data_query {
      query_statement = file("${path.module}/cur_query.sql")

      table_configurations = {
        "COST_AND_USAGE_REPORT" = {
          BILLING_VIEW_ARN                      = "arn:${local.partition}:billing::${local.account_id}:billingview/primary"
          TIME_GRANULARITY                      = "HOURLY"
          INCLUDE_RESOURCES                     = "TRUE"
          INCLUDE_SPLIT_COST_ALLOCATION_DATA    = "TRUE"
          INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY = "FALSE"
        }
      }
    }

    destination_configurations {
      s3_destination {
        s3_bucket = aws_s3_bucket.cur_bucket.id
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
