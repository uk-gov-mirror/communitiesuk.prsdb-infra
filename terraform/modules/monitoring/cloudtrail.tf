


resource "aws_cloudtrail" "main" {
  name                          = "prsd-cloudtrail-${var.environment_name}"
  s3_bucket_name                = module.s3_bucket.bucket
  kms_key_id                    = aws_kms_key.main.arn
  include_global_service_events = true
  is_multi_region_trail         = true
  cloud_watch_logs_group_arn    = "${module.cloudtrail_cloudwatch_group.log_group_arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch_role.arn
  enable_log_file_validation    = true

  advanced_event_selector {
    name = "Log management events"
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  dynamic "advanced_event_selector" {
    for_each = var.enable_kms_cloudtrail_events ? [1] : []
    content {
      name = "Log KMS data events"
      field_selector {
        field  = "eventCategory"
        equals = ["Data"]
      }
      field_selector {
        field  = "resources.type"
        equals = ["AWS::KMS::Key"]
      }
    }
  }

}

module "cloudtrail_cloudwatch_group" {
  source = "../encrypted_log_group"

  log_group_name     = "prsd-cloudtrail-${var.environment_name}"
  log_retention_days = var.cloudwatch_log_expiration_days
}



