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
    user_identity = event['requestContext']['authorizer']['claims']['sub']
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
            KeyConditionExpression = Key('HK').eq("USER#" + user_identity) & Key('SK').begins_with("CONV#")
        ).get("Items", [])

        return {
            "statusCode": "200",
            "headers": {"Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*",
                        "Access-Control-Allow-Methods": "GET, OPTIONS"},
            "data": json.dumps({"resumes": resumes, "job_listings": job_listings, "conversations": conversations})
        }

    except Exception as e:
        return {
            "statusCode": "500",
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, OPTIONS"},
            "body": json.dumps({"error": f"Interal DynamoDB error. Couldn't retrieve data. {e}"})
        }