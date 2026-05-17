variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Used as the S3 bucket name prefix"
  type        = string
  default     = "stock-market-data"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "indianapi_key" {
  description = "API key for stock.indianapi.in — pass via TF_VAR_indianapi_key env var, never hardcode"
  type        = string
  sensitive   = true
}
