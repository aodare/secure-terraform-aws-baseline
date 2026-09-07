# Intentionally insecure training example.
# Do not deploy this configuration.
# It exists only to demonstrate that Checkov detects common S3 security issues.

resource "aws_s3_bucket" "public_training_example" {
  bucket_prefix = "insecure-training-example-"

  tags = {
    Name    = "insecure-training-example"
    Purpose = "Checkov detection demonstration"
  }
}

resource "aws_s3_bucket_acl" "public_training_example" {
  bucket = aws_s3_bucket.public_training_example.id
  acl    = "public-read"
}
