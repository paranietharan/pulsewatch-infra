# ==============================================================================
# Terraform Remote State Backend Bootstrap
# Provisions Amazon S3 (encrypted + versioned) and DynamoDB (locking table)
# Run this ONCE to prepare AWS for remote state locking before applying main infrastructure.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "aws_region" {
  description = "AWS region for Terraform state storage"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project identifier for naming resources"
  type        = string
  default     = "pulsewatch"
}

provider "aws" {
  region = var.aws_region
}

# Unique random suffix for globally unique S3 bucket name
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ------------------------------------------------------------------------------
# S3 Bucket for Terraform State
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "state" {
  bucket        = "${var.project_name}-tf-state-${random_string.suffix.result}"
  force_destroy = false

  tags = {
    Project   = "PulseWatch"
    Purpose   = "Terraform Remote State"
    ManagedBy = "Terraform"
  }
}

# Enable versioning so all state history is retained
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable AES256 server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access to state bucket
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------------------------
# DynamoDB Table for Terraform State Locking
# ------------------------------------------------------------------------------
resource "aws_dynamodb_table" "locks" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project   = "PulseWatch"
    Purpose   = "Terraform State Locking"
    ManagedBy = "Terraform"
  }
}

# ------------------------------------------------------------------------------
# Outputs & Backend Configuration Snippet
# ------------------------------------------------------------------------------
output "s3_bucket_name" {
  description = "Name of the S3 bucket created for Terraform remote state"
  value       = aws_s3_bucket.state.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table created for state locking"
  value       = aws_dynamodb_table.locks.name
}

output "backend_config_snippet" {
  description = "Backend block configuration for terraform/versions.tf"
  value       = <<EOT
backend "s3" {
  bucket         = "${aws_s3_bucket.state.bucket}"
  key            = "eks/terraform.tfstate"
  region         = "${var.aws_region}"
  dynamodb_table = "${aws_dynamodb_table.locks.name}"
  encrypt        = true
}
EOT
}
