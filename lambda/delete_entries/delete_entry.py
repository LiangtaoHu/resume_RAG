import boto3
import json
import os

DYNAMO_DB_TABLE = os.environ["DYNAMO_DB_TABLE"]

dynamo_client = boto3.resource("dynamodb")
dynamo_table = dynamo_client.Table(DYNAMO_DB_TABLE)

def handler(event, context):
    # User identity present?
    user_identity = event['requestContext']['authorizer']['claims']['sub']
    if not user_identity:
        return {
            "statusCode": 401,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Unauthorized: Missing idToken"})
        }
    body = json.loads(event.get('body', '{}'))
    conversation_id = body.get('conversation_id', "")
    resume_id = body.get('resume_id', "")
    listing_id = body.get('listing_id', "")

    try:
        if conversation_id:
            q_response = dynamo_table.get_item(
                Key = {
                    'HK': f"USER#{user_identity}",
                    'SK': f"CONV#{conversation_id}"
                }
            )
            conversation = q_response.get("Item", {})
            if conversation:
                del_response = dynamo_table.delete_item(
                    Key = {
                        'HK': f"USER#{user_identity}",
                        'SK': f"CONV#{conversation_id}"
                    }
                )
        elif resume_id:
            q_response = dynamo_table.get_item(
                Key = {
                    'HK': f"USER#{user_identity}",
                    'SK': f"CONV#{resume_id}"
                }
            )
            resume = q_response.get("Item", {})
            if resume:
                del_response = dynamo_table.delete_item(
                    Key = {
                        'HK': f"USER#{user_identity}",
                        'SK': f"CONV#{resume_id}"
                    }
                )

        elif listing_id:
            q_response = dynamo_table.get_item(
                Key = {
                    'HK': f"USER#{user_identity}",
                    'SK': f"CONV#{listing_id}"
                }
            )
            listing = q_response.get("Item", {})
            if listing:
                del_response = dynamo_table.delete_item(
                    Key = {
                        'HK': f"USER#{user_identity}",
                        'SK': f"CONV#{listing_id}"
                    }
                )
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"DynamoDB error": str(e)})
        }
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "message": "Items successfully deleted.",
        })
    }