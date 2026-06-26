import os
import boto3
from boto3.dynamodb.conditions import Key
import json

'''
This Lambda Function will be responsible for displaying the User's current resumes & parsed job listings on the /chat page.
It'll return by querying the DynamoDB table for both pieces of data and return them in two dictionaries.
This data will be used for the "Choose 2" option to create a new conversation with the Bedrock Agent
'''
DYNAMO_DB_TABLE = os.environ["DYNAMO_DB_TABLE"]

dynamo_client = boto3.resource("dynamodb")
dynamo_table = dynamo_client.Table(DYNAMO_DB_TABLE)

def handler(event, context):
    # Retrieving user_identity
    raw_headers = event.get("headers", {})
    headers = {k.lower(): v for k, v in raw_headers.items()}

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
    
    try:
        resumes = dynamo_table.query(
            KeyConditionExpression = Key('HK').eq("USER#" + user_identity) & Key('SK').begins_with('RESUME#'),
        ).get("Items", [])
        job_listings = dynamo_table.query(
            KeyConditionExpression = Key('HK').eq("USER#" + user_identity) & Key('SK').begins_with('JOB#'),
        ).get("Items", [])
        conversations = dynamo_table.query(
            KeyConditionsExpression = Key('HK').eq("USER#" + user_identity) & Key('SK').begins_with("CONV#")
        )

        return {
            "statusCode": "200",
            "headers": {"Content-Type": "application/json"},
            "data": json.dumps({"resumes": resumes, "job_listings": job_listings, "conversations": conversations})
        }

    except Exception:
        return {
            "statusCode": "500",
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Interal DynamoDB error. Couldn't retrieve data."})
        }