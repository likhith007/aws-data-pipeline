# Learnings

Personal notes from building this project. Updated as each new concept is covered.

---

## AWS S3

- S3 is a global service but data physically lives in the region where the bucket was created
- Bucket names are globally unique across all AWS accounts
- There are no real folders in S3 — everything is a flat key-value store. What looks like a folder is just an object whose key contains `/` (e.g. `bronze/file.json`)
- Always block public access on buckets unless explicitly needed
- Naming convention used: `{project}-{environment}` (e.g. `stock-market-data-dev`)
- **Medallion architecture** — a standard data lake pattern with three zones:
  - `bronze` — raw data as-is from the source
  - `silver` — cleaned and transformed data
  - `gold` — aggregated, analytics-ready data
- Using date as a filename prefix (`2025-05-18.json`) is simpler than nested date folders for daily data

---

## AWS Lambda

- Lambda runs code without managing servers — you only pay per invocation
- Python's `requests` library is not built into the Lambda runtime — it must be packaged with the function
- Best way to handle dependencies: use a **Docker container image** — install anything you want in the Dockerfile
- Lambda environment variables are the right place to pass config like API keys (never hardcode)
- `boto3` (AWS SDK) is pre-installed in the Lambda runtime — no need to add it to `requirements.txt`
- Lambda logs automatically go to **CloudWatch Logs** — useful for debugging
- `source_code_hash` in Terraform ensures Lambda redeploys when code changes

---

## AWS ECR (Elastic Container Registry)

- ECR is AWS's private Docker registry — stores container images for use with Lambda, ECS, etc.
- Images are pushed with a tag like `<account_id>.dkr.ecr.<region>.amazonaws.com/<repo>:latest`
- Must authenticate Docker to ECR before pushing: `aws ecr get-login-password | docker login ...`
- Always build with `--platform linux/amd64` on Mac (Apple Silicon) to ensure compatibility with Lambda's Linux runtime
- `MUTABLE` image tags allow overwriting `latest` on each deploy

---

## AWS EventBridge

- EventBridge is a serverless event bus — used here purely as a scheduler
- Uses a 6-field cron format (different from standard Unix cron): `cron(Minutes Hours DayOfMonth Month DayOfWeek Year)`
- `?` is used in DayOfMonth when DayOfWeek is specified (they can't both be set)
- Scheduled rules are **free** — no cost for time-based triggers
- Three resources needed to wire EventBridge → Lambda:
  1. `aws_cloudwatch_event_rule` — defines the schedule
  2. `aws_cloudwatch_event_target` — points the rule at the Lambda
  3. `aws_lambda_permission` — grants EventBridge permission to invoke Lambda

---

## AWS IAM

- Every AWS service needs an IAM role to interact with other services
- Lambda needs an IAM role with:
  - `AWSLambdaBasicExecutionRole` — to write logs to CloudWatch
  - A custom policy scoped to `s3:PutObject` on `bronze/*` only — least privilege
- Scoping permissions to specific prefixes (`/bronze/*`) is better than granting full bucket access

---

## Terraform

- `terraform init` — downloads providers (run once, or after provider changes)
- `terraform plan` — previews changes without touching AWS
- `terraform apply` — creates/updates real AWS resources
- `terraform destroy` — tears everything down
- `terraform state rm` — removes a resource from state without deleting it from AWS (useful when state gets out of sync)
- **Never store credentials in `.tf` files** — use `TF_VAR_` environment variables for sensitive values
- `sensitive = true` on a variable hides its value in `terraform plan` output
- Switching regions on an existing deployment requires destroy + re-apply — resources are region-specific
- `data "aws_caller_identity"` and `data "aws_region"` are useful to confirm which account and region Terraform is targeting
- `null_resource` with `local-exec` provisioner runs shell commands as part of `terraform apply` (used here to build and push Docker images)
- File layout kept flat (no modules yet) for simplicity at this learning stage

---

## AWS Pricing Lessons

- EventBridge scheduled rules — **free**
- Lambda — 1M free invocations/month, essentially free for daily runs
- S3 — negligible cost for small JSON files
- ECR — ~$0.10/GB/month for image storage
- Step Functions — $0.025 per 1,000 state transitions
- **Redshift** — most expensive service planned; watch costs carefully when added
- Always set a billing budget with email alerts in AWS Console → Billing → Budgets

---

## Architecture Decisions

| Decision | Why |
|---|---|
| Single S3 bucket with prefixes over multiple buckets | Simpler to manage, lower overhead |
| Docker image over zip packaging | Can install any Python package freely |
| Date as S3 filename (`2025-05-18.json`) | One file per trading day, easy to find |
| IST date label on S3 files | Matches the actual trading day, not UTC |
| EventBridge → Lambda (direct for now) | Step Functions will be added when Glue is introduced |
| Mumbai (`ap-south-1`) region | Closest to IST timezone, lower latency, supports all planned services |

---

## Planned Next Steps

- [ ] AWS Glue job — read bronze JSON, clean and transform, write Parquet to silver
- [ ] AWS Step Functions — orchestrate Lambda + Glue jobs in sequence
- [ ] EventBridge → Step Functions (replace direct Lambda trigger)
- [ ] Amazon Redshift — load gold data for SQL querying
