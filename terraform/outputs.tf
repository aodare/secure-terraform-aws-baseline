output "bucket_name" {
  description = "Name of the secure S3 bucket created by this baseline."
  value       = aws_s3_bucket.secure_data.bucket
}

output "bucket_arn" {
  description = "ARN of the secure S3 bucket."
  value       = aws_s3_bucket.secure_data.arn
}

output "security_controls" {
  description = "Security controls configured for the S3 bucket."
  value = {
    public_access_blocked = true
    versioning_enabled    = true
    encryption_enabled    = true
    lifecycle_configured  = true
  }
}
