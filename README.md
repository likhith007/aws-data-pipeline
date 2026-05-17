# Stock Market Data Pipeline

A hands-on AWS data engineering project that ingests trending stock data daily and stores it in a medallion architecture on S3. Built incrementally to learn AWS Glue, Redshift, Step Functions, Lambda, and S3.

## Architecture

```
EventBridge (Mon-Fri 8pm IST)
    └──► Step Functions State Machine (planned)
              ├── Step 1: Lambda  → fetches API → stores raw JSON in bronze
              ├── Step 2: Glue    → cleans data → writes Parquet to silver (planned)
              └── Step 3: Glue    → aggregates  → writes to gold (planned)
                                                        │
                                                   Redshift (planned)
```

**Data lake — single S3 bucket (`stock-market-data-dev`) with medallion zones:**

```
stock-market-data-dev/
├── bronze/trending_stocks/YYYY-MM-DD.json   ← raw API response, written by Lambda
├── silver/                                  ← cleaned Parquet (Glue, coming soon)
└── gold/                                    ← analytics-ready (Redshift, coming soon)
```

## Services Used

| Service | Purpose |
|---|---|
| **S3** | Data lake storage (bronze / silver / gold zones) |
| **Lambda** | Fetches trending stocks from IndianAPI daily |
| **ECR** | Stores the Lambda Docker container image |
| **EventBridge** | Schedules Lambda Mon-Fri at 8pm IST |
| **IAM** | Scoped permissions for Lambda to write to S3 |
| **Glue** | ETL jobs (coming soon) |
| **Step Functions** | Pipeline orchestration (coming soon) |
| **Redshift** | Data warehouse (coming soon) |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) configured with `aws configure`
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) running
- An API key from [indianapi.in](https://indianapi.in)

## Deploying

```bash
# 1. Set your API key
export TF_VAR_indianapi_key="your-api-key-here"

# 2. Build and push the Docker image to ECR
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  <account_id>.dkr.ecr.ap-south-1.amazonaws.com

docker build --platform linux/amd64 \
  -t <account_id>.dkr.ecr.ap-south-1.amazonaws.com/stock-market-data-stock-ingestion:latest \
  lambda/stock_ingestion

docker push <account_id>.dkr.ecr.ap-south-1.amazonaws.com/stock-market-data-stock-ingestion:latest

# 3. Deploy infrastructure
cd terraform
terraform init
terraform apply
```

## Testing

Invoke the Lambda manually (without waiting for the 8pm schedule):

```bash
aws lambda invoke \
  --function-name stock-market-data-stock-ingestion-dev \
  --payload '{}' \
  --region ap-south-1 \
  response.json && cat response.json
```

Verify the file landed in S3:

```bash
aws s3 ls s3://stock-market-data-dev/bronze/trending_stocks/ --region ap-south-1
```

## Tear Down

```bash
cd terraform
terraform destroy
```
