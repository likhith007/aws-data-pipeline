import json
import os
from datetime import datetime, timezone, timedelta

import boto3
import requests

# ── Config ────────────────────────────────────────────────────────────────────

API_URL   = "https://stock.indianapi.in/trending"
API_KEY   = os.environ["INDIANAPI_KEY"]       # set as Lambda env var in Terraform
BUCKET    = os.environ["S3_BUCKET"]           # injected by Terraform
ZONE      = "bronze"

# ── Helpers ───────────────────────────────────────────────────────────────────

def fetch_trending() -> dict:
    """Call the IndianAPI trending endpoint and return parsed JSON."""
    response = requests.get(
        API_URL,
        headers={"x-api-key": API_KEY},
        timeout=10
    )
    response.raise_for_status()
    return response.json()


def s3_key(now: datetime) -> str:
    """
    Store one file per trading day using date as filename prefix.
    e.g. bronze/trending_stocks/2025-05-18.json
    """
    ist = now + timedelta(hours=5, minutes=30)   # convert UTC → IST for the date label
    return f"{ZONE}/trending_stocks/{ist.strftime('%Y-%m-%d')}.json"


# ── Lambda entry point ────────────────────────────────────────────────────────

def lambda_handler(event, context):
    now = datetime.now(timezone.utc)

    # 1. Fetch raw data
    data = fetch_trending()

    top_gainers = data["trending_stocks"]["top_gainers"]
    top_losers  = data["trending_stocks"]["top_losers"]

    print(f"Fetched {len(top_gainers)} gainers, {len(top_losers)} losers")

    # 2. Build the payload — store the full raw response + metadata
    payload = {
        "fetched_at_utc": now.isoformat(),
        "source":         API_URL,
        "raw":            data,
    }

    # 3. Upload to S3 bronze zone
    key = s3_key(now)
    boto3.client("s3").put_object(
        Bucket=BUCKET,
        Key=key,
        Body=json.dumps(payload, indent=2),
        ContentType="application/json",
    )

    print(f"Saved to s3://{BUCKET}/{key}")
    return {"statusCode": 200, "key": key}
