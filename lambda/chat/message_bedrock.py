import os
import json
import boto3
import awslambda

REGION_NAME = os.environ['REGION_NAME']
RESUME_BUCKET = os.environ['RESUME_BUCKET']
AGENT_ID = os.environ["AGENT_ID"]
KB_ID = os.environ["KB_ID"]

bedrock_client = boto3.client(service_name="bedrock-agent-runtime", region_name=REGION_NAME)

'''
TODO: Should be made into an infrastructure step
bedrock_client.associate_agent_knowledge_base(
    agentId=AGENT_ID,
    agentVersion='',
    knowledgeBaseId = KB_ID,
)
'''
def lambda_handler(event, context):
    '''
    WorkFlow:
        1. Authentication should've already occured. So our user-id is a valid user-id
        2. Generate a valid session id OR if session id is already specified in header use that
        3a. IF session id already exists, just send user message to that session-id as conversation history is stored.
        3b. IF session id DOESNT exist, we must send resume PDF with prompt and specified Job Listing to the agent.
        4. Return agent message
    '''
    raw_headers = event.get("headers", {})
    headers = {k.lower(): v for k, v in raw_headers.items()}
    # Step 1
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
    if not user_identity:
        return {
            "statusCode": 401,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Unauthorized: Missing idToken"})
        }
    # Step 2
    session_id = headers.get("session_id", "")
    


    response = bedrock_client.invoke_agent(
        agentAliasID = "",
        sessionId = session_id,
        agentId = AGENT_ID,
        inputText = prompt,
        sessionState = {
            'knowledgeBaseConfigurations': [{
                'knowledgeBaseId': KB_ID,
                'retrievalConfiguration': {
                    'vectorSearchConfiguration': {
                        'filter': {
                            'equals': {
                                "key": "user-id",
                                "value": user_id
                            }
                        }
                    }
                }
            }],
            'sessionAttributes': {
                'user-id': user_id
            }
        }
    )