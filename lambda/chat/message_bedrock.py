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

def get_header_values(headers):
    cookies = {}
    if "cookie" in headers:
        # Loop through all the cookies
        for cookie in headers["cookie"]:
            # We are mainly interested in the value as the key for each is just "cookie"
            # The value can be multi-cookie per actual cookie, with a separator of ";"
            cookie_string = cookie.get("value", "")
            for cookie_instance in cookie_string.split(";"):
                # We split again on the equals sign
                if "=" in cookie_instance:
                    key, value = cookie_instance.split("=", 1)
                    cookies[key.strip()] = value.strip()
    user_identity = cookies.get("idToken")
    conversation_id = headers.get("conversation_id", "")
    # TODO: Do we need to return in case there's no user_identity?
    return user_identity, conversation_id

def lambda_handler(event, context):
    # We are already authenticated
    raw_headers = event.get("headers", {})
    headers = {k.lower(): v for k, v in raw_headers.items()}
    user_identity, conversation_id = get_header_values(headers)
    # Conversation ID check
    response = dynamo_table.get_item(
        Key = {
            'HK': f"USER#{user_identity}",
            'SK': f"CONV#{conversation_id}"
        }
    )
    conversation = response.get("Item", {})
    chatHistory = conversation.get("chatHistory", [])
    resume_id = conversation.get("resumeID", "")
    if conversation == {}:
        resume_id = headers.get("resume_id", "")
        job_id = headers.get("job_id", "")
        # If either of these are empty strings, we cannot help you
        if not resume_id or not job_id:
            return {
                'statusCode': "400",
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "Neither conversation id or resume and job ids were provided. Invalid Request."})
            }

        dynamo_table.put_item(
            Item = {
                'HK': f"USER#{user_identity}",
                'SK': f"CONV#{resume_id}-{job_id}",
                'resumeID': resume_id,
                'jobID': job_id,
                'chatHistory': chatHistory
            }
        )
    # Now we definitely have a conversation with this id in the database. We just need to determine if we are in the 1 hour message timelimit
    one_hour_ago = time.time() - 3600 # 3600 seconds in an hour
    buffer_time = 10 # 10 seconds
    job_result = dynamo_table.get_item(
        Key = {
            'HK': user_identity,
            'SK': f"JOB#{job_id}"
        }
    )
    job_object = job_result.get("Item", {})
    if job_object == {}:
        return {
            'statusCode': "400",
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Job id is invalid."})
        }
    body = event.get("body", {})
    user_message = body.get("user_message", "")
    if user_message == "":
        return {
            'statusCode': "400",
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "User message is invalid."})
        }
    # We have chatHistory and our message was more than an hour ago, send entire chat History with it
    if chatHistory != [] and chatHistory[-1]['timestamp'] < (one_hour_ago + buffer_time):
        user_message = "CHAT HISTORY UP UNTIL THIS POINT: \n" + json.dumps(chatHistory) + "\n" + "USER MESSAGE: \n" + user_message
    else:
        resume_item = dynamo_table.get_item(
            Key = {
                'HK': f"USER#{user_identity}",
                'SK': f"RESUME#{resume_id}"
            }
        )
        resume = resume_item.get("Item")
        resume_text = resume.get("CachedText", "")
        if resume_text == "":
            return {
                'statusCode': "400",
                "headers": {"Content-Type": "application/json"},
                "body": json.dumps({"error": "Resume is empty."})
            }
        user_message = "USER RESUME: \n" + resume_text + "\n" + "USER MESSAGE: \n" + user_message
    response = bedrock_client.invoke_agent(
        agentId = AGENT_ID,
        agentAliasId = AGENT_ALIAS_ID,
        inputText = user_message,
        sessionId = conversation_id,
        sessionState = {
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
                        # implicit filtering?
                        # number of results?
                    },
                    # returnControlInvocationResults
                }
            }]
        }
    )
    return {
        'statusCode': 200,
        "headers": {"Content-Type": "application/json"},
        'body': {
            'agent_text': derive_full_text(response)
        }
    }