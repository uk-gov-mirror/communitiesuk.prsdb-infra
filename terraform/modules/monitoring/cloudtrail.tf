


locals {
  # High volume (i.e. cryptographic) operations that we want to enable/disable for cost saving via
  # var.enable_kms_cloudtrail_events - these are MANAGEMENT events
  # see https://docs.aws.amazon.com/awscloudtrail/latest/userguide/logging-management-events-with-cloudtrail.html
  # and associated quotas: https://docs.aws.amazon.com/kms/latest/developerguide/requests-per-second.html
  kms_cryptographic_event_names = [
    "Decrypt",
    "Encrypt",
    "GenerateDataKey",
    "GenerateDataKeyPair",
    "GenerateDataKeyPairWithoutPlaintext",
    "GenerateDataKeyWithoutPlaintext",
    "GenerateMac",
    "ReEncrypt",
    "Sign",
    "Verify",
    "VerifyMac",
    "GetPublicKey",
  ]
}

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

  # Log all non cryptographic KMS management events
  advanced_event_selector {
    name = "Log KMS events (excluding cryptographic KMS events)"
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
    field_selector {
      field  = "eventSource"
      equals = ["kms.amazonaws.com"]
    }
    field_selector {
      field      = "eventName"
      not_equals = local.kms_cryptographic_event_names
    }
  }

  # Include the cryptographic events if enable_kms_cloudtrail_events is set to true
  dynamic "advanced_event_selector" {
    for_each = var.enable_kms_cloudtrail_events ? [1] : []
    content {
      name = "Log KMS cryptographic operation events"
      field_selector {
        field  = "eventCategory"
        equals = ["Management"]
      }
      field_selector {
        field  = "eventSource"
        equals = ["kms.amazonaws.com"]
      }
      field_selector {
        field  = "eventName"
        equals = local.kms_cryptographic_event_names
      }
    }
  }

}

module "cloudtrail_cloudwatch_group" {
  source = "../encrypted_log_group"

  log_group_name     = "prsd-cloudtrail-${var.environment_name}"
  log_retention_days = var.cloudwatch_log_expiration_days
}



