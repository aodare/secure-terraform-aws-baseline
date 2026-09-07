terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "secure_data" {
  bucket_prefix = "${var.project_name}-"

  tags = {
    Name        = "${var.project_name}-secure-data"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "Security baseline demonstration"
  }
}

resource "aws_s3_bucket_public_access_block" "secure_data" {
  bucket = aws_s3_bucket.secure_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "secure_data" {
  bucket = aws_s3_bucket.secure_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "s3" {
  description             = "KMS key for the secure Terraform baseline S3 bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-s3-kms-key"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "S3 default encryption"
  }
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.project_name}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure_data" {
  bucket = aws_s3_bucket.secure_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "secure_data" {
  bucket = aws_s3_bucket.secure_data.id

  rule {
    id     = "transition-noncurrent-versions"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

resource "aws_s3_bucket" "access_logs" {
  bucket_prefix = "${var.project_name}-access-logs-"

  tags = {
    Name        = "${var.project_name}-access-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "S3 access logging destination"
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_logging" "secure_data" {
  bucket        = aws_s3_bucket.secure_data.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "secure-data/"
}
