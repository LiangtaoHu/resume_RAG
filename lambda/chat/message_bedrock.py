import os
import json
import time
import boto3

REGION_NAME = os.environ['REGION_NAME']
AGENT_ID = os.environ["AGENT_ID"]
AGENT_ALIAS_ID = os.environ["AGENT_ALIAS_ID"]
KB_ID = os.environ["KB_ID"]
DYNAMO_DB_TABLE = os.environ["DYNAMO_DB_TABLE"]

dynamo_client = boto3.resource("dynamodb")
dynamo_table = dynamo_client.Table(DYNAMO_DB_TABLE)

bedrock_client = boto3.client(service_name="bedrock-agent-runtime", region_name=REGION_NAME)


def derive_full_text(response):
    full_text = ""
    for event in response.get("completion", []):
        if "chunk" in event:
            full_text += event["chunk"]["bytes"].decode('utf-8')
    return full_text


def cors_headers(event):
    """Echo the caller's origin. API Gateway CORS handles preflight, but does
    not inject these onto proxied Lambda responses, so every path uses this."""
    origin = (event.get("headers", {}) or {}).get("origin", "*")
    return {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": origin,
    }


def get_user_identity(event):
    """Pull the authenticated user's Cognito `sub` from the JWT authorizer."""
    claims = (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("jwt", {})
        .get("claims", {})
    )
    return claims.get("sub")


def parse_body(event):
    """API Gateway HTTP API (payload_format_version 2.0) hands us a string body."""
    raw = event.get("body")
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}


def lambda_handler(event, context):
    headers = cors_headers(event)
    user_identity = get_user_identity(event)
    if not user_identity:
        return {
            "statusCode": 401,
            "headers": headers,
            "body": json.dumps({"error": "Unauthorized: Missing identity from authorizer"})
        }

    # conversation_id now arrives as a custom header (was previously pulled from
    # the cookie via get_header_values()).
    raw_headers = event.get("headers", {}) or {}
    headers_lower = {k.lower(): v for k, v in raw_headers.items()}
    conversation_id = headers_lower.get("conversation_id", "")

    response = dynamo_table.get_item(
        Key={
            'HK': f"USER#{user_identity}",
            'SK': f"CONV#{conversation_id}"
        }
    )
    conversation = response.get("Item", {})
    chatHistory = conversation.get("chatHistory", [])
    resume_id = conversation.get("resumeID", "")
    if conversation == {}:
        resume_id = headers_lower.get("resume_id", "")
        job_id = headers_lower.get("job_id", "")
        if not resume_id or not job_id:
            return {
                "statusCode": 400,
                "headers": headers,
                "body": json.dumps({"error": "Neither conversation id or resume and job ids were provided. Invalid Request."})
            }

        dynamo_table.put_item(
            Item={
                'HK': f"USER#{user_identity}",
                'SK': f"CONV#{resume_id}-{job_id}",
                'resumeID': resume_id,
                'jobID': job_id,
                'chatHistory': chatHistory
            }
        )

    one_hour_ago = time.time() - 3600
    buffer_time = 10
    job_result = dynamo_table.get_item(
        Key={
            'HK': user_identity,
            'SK': f"JOB#{job_id}"
        }
    )
    job_object = job_result.get("Item", {})
    if job_object == {}:
        return {
            "statusCode": 400,
            "headers": headers,
            "body": json.dumps({"error": "Job id is invalid."})
        }

    body = parse_body(event)
    user_message = body.get("user_message", "")
    if user_message == "":
        return {
            "statusCode": 400,
            "headers": headers,
            "body": json.dumps({"error": "User message is invalid."})
        }

    if chatHistory != [] and chatHistory[-1]['timestamp'] < (one_hour_ago + buffer_time):
        user_message = "CHAT HISTORY UP UNTIL THIS POINT: \n" + json.dumps(chatHistory) + "\n" + "USER MESSAGE: \n" + user_message
    else:
        resume_item = dynamo_table.get_item(
            Key={
                'HK': f"USER#{user_identity}",
                'SK': f"RESUME#{resume_id}"
            }
        )
        resume = resume_item.get("Item")
        resume_text = resume.get("cachedText", "")
        if resume_text == "":
            return {
                "statusCode": 400,
                "headers": headers,
                "body": json.dumps({"error": "Resume is empty."})
            }
        user_message = "USER RESUME: \n" + resume_text + "\n" + "USER MESSAGE: \n" + user_message

    response = bedrock_client.invoke_agent(
        agentId=AGENT_ID,
        agentAliasId=AGENT_ALIAS_ID,
        inputText=user_message,
        sessionId=conversation_id,
        sessionState={
            "knowledgeBaseConfigurations": [{
                "knowledgeBaseId": KB_ID,
                "retrievalConfiguration": {
                    "vectorSearchConfiguration": {
                        'filter': {
                            'andAll': [{
                                'equals': {
                                    "key": "user-id",
                                    "value": user_identity
                                }
                            },
                            {
                                'equals': {
                                    "key": "title",
                                    "value": f"{job_object['company']}-{job_object['position']}"
                                }
                            }]
                        }
                    },
                }
            }]
        }
    )
    return {
        "statusCode": 200,
        "headers": headers,
        "body": json.dumps({
            "agent_text": derive_full_text(response)
        })
    }
