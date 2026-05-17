# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an AWS data pipeline project. The repository is in its initial state — update this file as the architecture is established.

## Commands

All Terraform commands are run from the `terraform/` directory.

```bash
cd terraform

terraform init          # download providers (first time, or after provider changes)
terraform plan          # preview what will be created/changed/destroyed
terraform apply         # create/update real AWS resources
terraform destroy       # tear everything down when done experimenting
terraform output        # print bucket names after apply
```

AWS credentials must be configured before running any of these — either via `~/.aws/credentials` (set up with `aws configure`) or environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`).

## Architecture

**IaC:** Terraform (`terraform/`)

**Data lake — single S3 bucket with medallion zones:**

```
stock-market-data-dev/
├── bronze/trending_stocks/YYYY-MM-DD.json  ← raw JSON, written by Lambda
├── silver/                                 ← cleaned Parquet (Glue, planned)
└── gold/                                   ← analytics-ready (Redshift, planned)
```

One file per trading day, date in IST (e.g. `bronze/trending_stocks/2025-05-18.json`).

**Lambda (`lambda/stock_ingestion/handler.py`):**
Fetches trending stocks from `stock.indianapi.in` daily at 8pm IST (EventBridge cron `30 14 * * ? *` UTC) and stores the full raw JSON response in the bronze zone. API key is injected via `INDIANAPI_KEY` Lambda environment variable.

**Terraform layout:**
- `main.tf` — S3 bucket + public access block + zone prefixes
- `lambda.tf` — Lambda function, IAM role, EventBridge rule + target
- `variables.tf` / `locals.tf` / `outputs.tf` / `terraform.tfvars`

**Services planned (to be added incrementally):**
- AWS Glue — ETL jobs reading from `bronze`, writing to `silver`
- AWS Step Functions — orchestrate Glue jobs and Lambda
- Amazon Redshift — data warehouse reading from `gold`

**API key:** Pass via environment variable — never hardcode in `.tf` files or commit to git.
```bash
export TF_VAR_indianapi_key="your-key-here"
terraform apply
```
