import os
import json
import boto3
from boto3.dynamodb.conditions import Key, Attr

# Identity now arrives via the HTTP API JWT authorizer on
# event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"].

DYNAMO_DB_TABLE = os.environ["DYNAMO_DB_TABLE"]

dynamo_client = boto3.resource("dynamodb")
dynamo_table = dynamo_client.Table(DYNAMO_DB_TABLE)


def cors_headers(event):
    """Echo the caller's origin. API Gateway CORS handles preflight, but does
    not inject these onto proxied Lambda responses, so every path uses this."""
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


def handler(event, context):
    headers = cors_headers(event)
    user_identity = get_user_identity(event)
    if not user_identity:
        return {
            "statusCode": 401,
            "headers": headers,
            "body": json.dumps({"error": "Unauthorized: Missing identity from authorizer"})
        }

    try:
        resumes = dynamo_table.query(
            KeyConditionExpression=Key('HK').eq("USER#" + user_identity) & Key('SK').begins_with('RESUME#'),
        ).get("Items", [])
        # JOB# rows may have been soft-deleted (a `deletedAt` attribute set by
        # the job_crud Lambda). Filter them out so the SPA only ever sees
        # active listings. RESUME# / CONV# rows are not soft-deletable today.
        job_listings = dynamo_table.query(
            KeyConditionExpression=Key('HK').eq("USER#" + user_identity) & Key('SK').begins_with('JOB#'),
            FilterExpression=Attr('deletedAt').not_exists(),
        ).get("Items", [])
        conversations = dynamo_table.query(
            KeyConditionExpression=Key('HK').eq("USER#" + user_identity) & Key('SK').begins_with("CONV#")
        ).get("Items", [])

        return {
            "statusCode": 200,
            "headers": headers,
            "body": json.dumps({
                "resumes": resumes,
                "job_listings": job_listings,
                "conversations": conversations,
            })
        }

    except Exception:
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": "Internal DynamoDB error. Couldn't retrieve data."})
        }
