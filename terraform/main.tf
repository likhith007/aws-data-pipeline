terraform {
  required_version = ">= 1.5"

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

# ── Current AWS identity ──────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── Main data lake bucket ─────────────────────────────────────────────────────

resource "aws_s3_bucket" "learning_data" {
  bucket = "${var.project_name}-${var.environment}"

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "learning_data" {
  bucket = aws_s3_bucket.learning_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Medallion zone prefixes (bronze / silver / gold) ─────────────────────────
# These are empty placeholder objects that create the "folder" structure in S3.

resource "aws_s3_object" "bronze" {
  bucket = aws_s3_bucket.learning_data.id
  key    = "bronze/"
}

resource "aws_s3_object" "silver" {
  bucket = aws_s3_bucket.learning_data.id
  key    = "silver/"
}

resource "aws_s3_object" "gold" {
  bucket = aws_s3_bucket.learning_data.id
  key    = "gold/"
}
