"""
Add a JOB# row for the authenticated user.

Behavior:
  - UpdateItem with `attribute_not_exists(deletedAt)` guard. If the row already
    exists soft-deleted, this rejects with 409 so the user must explicitly
    restore (future endpoint) before re-adding.
  - Sets `addedAt`, `status: PENDING_INGEST`, and the metadata fields. The
    row does NOT trigger a Selenium scrape / KB ingestion — ingestion is the
    responsibility of a separate follow-up.
"""

import os
import json
import boto3
from datetime import datetime, timezone
from boto3.dynamodb.conditions import Attr

DYNAMO_DB_TABLE = os.environ["DYNAMO_DB_TABLE"]

dynamo_client = boto3.resource("dynamodb")
dynamo_table = dynamo_client.Table(DYNAMO_DB_TABLE)


def cors_headers(event):
    origin = (event.get("headers", {}) or {}).get("origin", "*")
    return {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": origin,
    }


def get_user_identity(event):
    claims = (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("jwt", {})
        .get("claims", {})
    )
    return claims.get("sub")


def parse_body(event):
    raw = event.get("body")
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}


def build_sk(company, position):
    # The JobListing side keeps existing keys as `JOB#<company>-<position>`.
    return f"JOB#{company}-{position}"


def handler(event, context):
    headers = cors_headers(event)
    user_identity = get_user_identity(event)
    if not user_identity:
        return {
            "statusCode": 401,
            "headers": headers,
            "body": json.dumps({"error": "Unauthorized: Missing identity from authorizer"}),
        }

    body = parse_body(event)
    company = (body.get("company") or "").strip()
    position = (body.get("position") or "").strip()
    url = (body.get("url") or "").strip()
    adzuna_id = (body.get("adzuna_id") or "").strip()

    if not company or not position or not url:
        return {
            "statusCode": 400,
            "headers": headers,
            "body": json.dumps({"error": "company, position, and url are required."}),
        }

    sk = build_sk(company, position)
    now = datetime.now(timezone.utc).isoformat()

    # Pre-flight: if the row exists and is soft-deleted, refuse.
    existing = dynamo_table.get_item(
        Key={"HK": f"USER#{user_identity}", "SK": sk}
    ).get("Item")
    if existing and "deletedAt" in existing:
        return {
            "statusCode": 409,
            "headers": headers,
            "body": json.dumps({"error": "Job was deleted; restore it before re-adding."}),
        }

    update_expr = "SET #company = :company, #position = :position, #url = :url, #status = :status, #addedAt = :now"
    expr_names = {
        "#company": "company",
        "#position": "position",
        "#url": "url",
        "#status": "status",
        "#addedAt": "addedAt",
    }
    expr_vals = {
        ":company": company,
        ":position": position,
        ":url": url,
        ":status": "PENDING_INGEST",
        ":now": now,
    }
    if adzuna_id:
        update_expr += ", #adzunaId = :adzunaId"
        expr_names["#adzunaId"] = "adzunaId"
        expr_vals[":adzunaId"] = adzuna_id

    try:
        dynamo_table.update_item(
            Key={"HK": f"USER#{user_identity}", "SK": sk},
            UpdateExpression=update_expr,
            ExpressionAttributeNames=expr_names,
            ExpressionAttributeValues=expr_vals,
            ConditionExpression=Attr("deletedAt").not_exists(),
        )
    except Exception as e:
        # Handle ConditionalCheckFailedException as a 409 (lost-race with soft-delete)
        return {
            "statusCode": 409,
            "headers": headers,
            "body": json.dumps({"error": f"Conflict: {e}"}),
        }

    return {
        "statusCode": 200,
        "headers": headers,
        "body": json.dumps({
            "sk": sk,
            "company": company,
            "position": position,
            "url": url,
            "status": "PENDING_INGEST",
            "addedAt": now,
        }),
    }
