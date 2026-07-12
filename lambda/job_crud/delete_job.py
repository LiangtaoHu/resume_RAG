"""
Soft-delete a JOB# row for the authenticated user.

Behavior:
  - UpdateItem sets `deletedAt` to an ISO-8601 timestamp. The row stays in
    DynamoDB; view_data filters it out via `attribute_not_exists(deletedAt)`.
  - Idempotent: if the row doesn't exist or is already soft-deleted, return
    200 anyway.
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

    if not company or not position:
        return {
            "statusCode": 400,
            "headers": headers,
            "body": json.dumps({"error": "company and position are required."}),
        }

    sk = build_sk(company, position)
    now = datetime.now(timezone.utc).isoformat()

    try:
        dynamo_table.update_item(
            Key={"HK": f"USER#{user_identity}", "SK": sk},
            UpdateExpression="SET #deletedAt = :now",
            ExpressionAttributeNames={"#deletedAt": "deletedAt"},
            ExpressionAttributeValues={":now": now},
        )
    except Exception as e:
        # The only failure mode here is access denied / throttling; surface it
        # to the SPA so the user knows to retry.
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": f"Soft-delete failed: {e}"}),
        }

    return {
        "statusCode": 200,
        "headers": headers,
        "body": json.dumps({"sk": sk, "deletedAt": now}),
    }
