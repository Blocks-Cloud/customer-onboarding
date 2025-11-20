
##############################
# BCM Data Exports (CUR 2.0) #
##############################

resource "aws_bcmdataexports_export" "cur2" {
  export {
    name        = local.export_name
    description = "CUR 2.0 export - ${upper(var.time_granularity)} granularity with resource IDs"

    data_query {
      query_statement = file("${path.module}/cur_query.sql")

      table_configurations = {
        "COST_AND_USAGE_REPORT" = {
          BILLING_VIEW_ARN                      = "arn:aws:billing::${data.aws_caller_identity.current.account_id}:billingview/primary"
          TIME_GRANULARITY                      = var.time_granularity
          INCLUDE_RESOURCES                     = var.include_resources ? "TRUE" : "FALSE"
          INCLUDE_SPLIT_COST_ALLOCATION_DATA    = "TRUE"
          INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY = "FALSE"
        }
      }
    }

    destination_configurations {
      s3_destination {
        s3_bucket = local.cur_bucket_name
        s3_prefix = "cur2"
        s3_region = data.aws_region.current.region

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

  depends_on = [aws_s3_bucket_policy.cur_bucket_policy]
}
