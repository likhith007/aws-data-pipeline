# ── ECR repository to store the Lambda container image ───────────────────────

resource "aws_ecr_repository" "stock_ingestion" {
  name                 = "${var.project_name}-stock-ingestion"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# ── Build and push the Docker image to ECR ───────────────────────────────────

locals {
  image_uri = "${aws_ecr_repository.stock_ingestion.repository_url}:latest"
  lambda_dir = "${path.module}/../lambda/stock_ingestion"
}

resource "null_resource" "build_and_push" {
  triggers = {
    requirements = filemd5("${local.lambda_dir}/requirements.txt")
    handler      = filemd5("${local.lambda_dir}/handler.py")
    dockerfile   = filemd5("${local.lambda_dir}/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<EOT
      aws ecr get-login-password --region ${var.aws_region} | \
        docker login --username AWS --password-stdin ${aws_ecr_repository.stock_ingestion.repository_url}

      docker build --platform linux/amd64 \
        -t ${local.image_uri} \
        ${local.lambda_dir}

      docker push ${local.image_uri}
    EOT
  }

  depends_on = [aws_ecr_repository.stock_ingestion]
}

# ── IAM role that Lambda assumes at runtime ───────────────────────────────────

resource "aws_iam_role" "stock_ingestion_lambda" {
  name = "${var.project_name}-stock-ingestion-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

# Basic execution: lets Lambda write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.stock_ingestion_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 write access — scoped only to the bronze prefix of our bucket
resource "aws_iam_role_policy" "lambda_s3_write" {
  name = "s3-bronze-write"
  role = aws_iam_role.stock_ingestion_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.learning_data.arn}/bronze/*"
    }]
  })
}

# ── Lambda function ───────────────────────────────────────────────────────────

resource "aws_lambda_function" "stock_ingestion" {
  function_name = "${var.project_name}-stock-ingestion-${var.environment}"
  description   = "Fetches trending stocks from IndianAPI and stores raw JSON in S3 bronze zone"

  package_type = "Image"
  image_uri    = local.image_uri
  timeout      = 30   # seconds — API call + S3 upload should finish well within this

  role = aws_iam_role.stock_ingestion_lambda.arn

  depends_on = [null_resource.build_and_push]

  environment {
    variables = {
      S3_BUCKET    = aws_s3_bucket.learning_data.bucket
      INDIANAPI_KEY = var.indianapi_key   # passed in via tfvars / env — never hardcode
    }
  }

  tags = local.common_tags
}

# ── EventBridge rule — fires daily at 8 pm IST (14:30 UTC) ───────────────────

resource "aws_cloudwatch_event_rule" "daily_8pm_ist" {
  name                = "${var.project_name}-daily-stock-ingest-${var.environment}"
  description         = "Triggers stock ingestion Lambda Mon-Fri at 20:00 IST (14:30 UTC)"
  schedule_expression = "cron(30 14 ? * MON-FRI *)"   # UTC — IST is UTC+5:30, weekdays only

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "invoke_stock_ingestion" {
  rule      = aws_cloudwatch_event_rule.daily_8pm_ist.name
  target_id = "StockIngestionLambda"
  arn       = aws_lambda_function.stock_ingestion.arn
}

# Grant EventBridge permission to invoke the Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stock_ingestion.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_8pm_ist.arn
}
