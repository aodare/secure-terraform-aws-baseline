variable "aws_region" {
  description = "AWS Region for the baseline. This project does not deploy resources in CI."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must resemble a valid AWS Region, for example us-east-1."
  }
}

variable "project_name" {
  description = "Short lowercase name used as the S3 bucket name prefix."
  type        = string
  default     = "secure-baseline"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.project_name))
    error_message = "project_name must be 3-30 characters using lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment label used for resource tagging."
  type        = string
  default     = "sandbox"

  validation {
    condition     = contains(["dev", "test", "sandbox", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, sandbox, staging, prod."
  }
}
