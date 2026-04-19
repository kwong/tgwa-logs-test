###############################################################################
# Consumer account — RAM accepter, TGW attachment, Flow Log
###############################################################################

# --- Accept RAM share (skip if org-level auto-accept is enabled) ---

resource "aws_ram_resource_share_accepter" "tgw" {
  count    = var.enable_ram_accepter ? 1 : 0
  provider = aws.consumer

  share_arn = aws_ram_principal_association.consumer.resource_share_arn
}

# --- TGW VPC Attachment ---

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  provider = aws.consumer

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = var.consumer_vpc_id
  subnet_ids         = var.consumer_subnet_ids

  tags = {
    Name = "tgw-attach-flow-log-lab"
  }

  depends_on = [aws_ram_resource_share_accepter.tgw]
}

# --- S3 bucket in consumer account (log destination for cross-account delivery) ---

data "aws_caller_identity" "hub" {
  provider = aws.hub
}

# CMK for TGW flow log bucket — key policy grants delivery.logs.amazonaws.com encrypt access
# scoped to the hub account so only hub-originated log delivery can use the key.
resource "aws_kms_key" "tgw_flow_logs" {
  provider                = aws.consumer
  description             = "CMK for TGW flow log bucket"
  deletion_window_in_days = 14
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "KeyAdminConsumerAccount"
        Effect   = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.consumer.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid      = "AWSLogDeliveryEncrypt"
        Effect   = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = ["kms:GenerateDataKey*"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.hub.account_id
          }
        }
      }
    ]
  })

  tags = {
    Name = "tgw-flow-log-bucket-key"
  }
}

resource "aws_kms_alias" "tgw_flow_logs" {
  provider      = aws.consumer
  name          = "alias/tgw-flow-log-bucket-key"
  target_key_id = aws_kms_key.tgw_flow_logs.key_id
}

resource "aws_s3_bucket" "tgw_flow_logs" {
  provider      = aws.consumer
  bucket        = "tgw-flow-logs-${data.aws_caller_identity.consumer.account_id}"
  force_destroy = true

  tags = {
    Name = "tgw-attachment-flow-log-lab"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tgw_flow_logs" {
  provider = aws.consumer
  bucket   = aws_s3_bucket.tgw_flow_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tgw_flow_logs.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_ownership_controls" "tgw_flow_logs" {
  provider = aws.consumer
  bucket   = aws_s3_bucket.tgw_flow_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "tgw_flow_logs" {
  provider = aws.consumer
  bucket   = aws_s3_bucket.tgw_flow_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy: allow delivery.logs.amazonaws.com (from hub account) to write flow logs
data "aws_iam_policy_document" "tgw_flow_logs_bucket" {
  provider = aws.consumer

  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.tgw_flow_logs.arn}/tgw-flow-logs/AWSLogs/${data.aws_caller_identity.hub.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.hub.account_id]
    }
  }

  statement {
    sid    = "AWSLogDeliveryAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.tgw_flow_logs.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.hub.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "tgw_flow_logs" {
  provider = aws.consumer
  bucket   = aws_s3_bucket.tgw_flow_logs.id
  policy   = data.aws_iam_policy_document.tgw_flow_logs_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.tgw_flow_logs]
}

# --- TGW Attachment Flow Log — Option 1: S3 cross-account delivery ---
# Hub creates the flow log (required); destination is S3 bucket in consumer account.
# FINDING 1: Consumer account → 403 UnauthorizedOperation
# FINDING 2: Hub + consumer CloudWatch → 400 LogDestination must match caller account
# TEST 3:    Hub + consumer S3 bucket (this test)

resource "aws_flow_log" "tgw_attachment" {
  provider = aws.hub

  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.this.id
  log_destination_type          = "s3"
  log_destination               = "${aws_s3_bucket.tgw_flow_logs.arn}/tgw-flow-logs/"
  max_aggregation_interval      = 60

  tags = {
    Name = "tgw-attachment-flow-log-lab"
  }

  depends_on = [aws_s3_bucket_policy.tgw_flow_logs]
}
