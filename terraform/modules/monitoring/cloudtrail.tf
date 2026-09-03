resource "aws_cloudtrail" "main" {
  name                          = "prsd-cloudtrail-${var.environment_name}"
  s3_bucket_name                = module.s3_bucket.bucket
  kms_key_id                    = aws_kms_key.main.arn
  include_global_service_events = true
  is_multi_region_trail         = true
  cloud_watch_logs_group_arn    = "${module.cloudtrail_cloudwatch_group.log_group_arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cloudwatch_role.arn
  enable_log_file_validation    = true

  # Ensures all management events are logged except KMS
  advanced_event_selector {
    name = "Log all management events (excluding KMS)"
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
    field_selector {
      field      = "eventSource"
      not_equals = ["kms.amazonaws.com"]
    }
  }

  # Include all KMS management events if enable_kms_cloudtrail_events is set to true. 
  # Disable for cost saving if enable_kms_cloudtrail_events is set to false
  dynamic "advanced_event_selector" {
    for_each = var.enable_kms_cloudtrail_events ? [1] : []
    content {
      name = "Log KMS management events"
      field_selector {
        field  = "eventCategory"
        equals = ["Management"]
      }
      field_selector {
        field  = "eventSource"
        equals = ["kms.amazonaws.com"]
      }
    }
  }
}

module "cloudtrail_cloudwatch_group" {
  source = "../encrypted_log_group"

  log_group_name     = "prsd-cloudtrail-${var.environment_name}"
  log_retention_days = var.cloudwatch_log_expiration_days
}
