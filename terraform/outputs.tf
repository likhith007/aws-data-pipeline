output "bucket_name" {
  description = "Main data lake bucket"
  value       = aws_s3_bucket.learning_data.bucket
}

output "bronze_path" {
  description = "S3 path for raw ingested data"
  value       = "s3://${aws_s3_bucket.learning_data.bucket}/bronze/"
}

output "silver_path" {
  description = "S3 path for cleaned / transformed data"
  value       = "s3://${aws_s3_bucket.learning_data.bucket}/silver/"
}

output "gold_path" {
  description = "S3 path for analytics-ready data"
  value       = "s3://${aws_s3_bucket.learning_data.bucket}/gold/"
}

output "lambda_function_name" {
  description = "Stock ingestion Lambda function name"
  value       = aws_lambda_function.stock_ingestion.function_name
}

output "aws_account_id" {
  description = "AWS account being deployed to"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region being deployed to"
  value       = data.aws_region.current.name
}
