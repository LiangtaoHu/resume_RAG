import os
import json
import boto3
import awslambda

# TODO: Fix other lambda functions, esp the parsing listing one to give a metadata tag of the user-id
# TODO: Need to add measures to ensure correct user-id, session-id, etc.
# TODO: Convert into Node.JS to use response streaming
# TODO: Add a way for bedrock to find S3 resumes and generate them
# TODO: Add a way for bedrock to find the correct vectors? Maybe make user specify which job?

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
@awslambda.stream_handler
def lambda_handler(event, context, response_stream):
    '''
    WorkFlow:
        1. Authentication should've already occured. So our user-id is a valid user-id
        2. Look at the session-id. If the session-id is valid, load up that conversation. If not present/valid, create a new session
        3. Send the user message
        4. Return agent message
    '''
    raw_headers = event.get("headers", {})
    headers = {k.lower(): v for k, v in raw_headers.items()}
    body = event.get("body", {})

    session_id = headers.get("session-id")
    user_id = headers.get("user-id")
    prompt = body.get("user-message")

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

    response_stream.write_content_type('text/plain')
    for event_chunk in response.get('completion', []):
        if 'chunk' in event_chunk:
            text_token = event_chunk['chunk']['bytes'].decode('utf-8')
            response_stream.write(text_token)