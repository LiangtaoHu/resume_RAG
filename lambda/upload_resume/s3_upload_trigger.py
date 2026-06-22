import os 
import boto3
from datetime import datetime, timezone
import time
import urllib.parse

'''
This defines the lambda function that is called when an object is successfully added into the resume folder.
It contacts the dynamo database and changes the s3 presigned URL saved from a PENDING to a COMPLETE status.
This is to ensure that each link can only be used once per expiration time period or equivalently one upload per expiration time period.
'''

REGION_NAME = os.environ['REGION_NAME']
DYNAMO_DB_NAME = os.environ['DYNAMO_DB_NAME']

dynamo_client = boto3.resource("dynamodb", region_name=REGION_NAME)
table = dynamo_client.Table(DYNAMO_DB_NAME)

def get_path(event):
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    # Split between "/" delimiter, first portion will be user identity the second will be the time
    user_identity = key.split("/")[0]
    return user_identity

def handler(event, context):
    user_identity = get_path(event)

    response = table.get_item(
        Key = {
            'HK': user_identity,
            'SK': "Link"
        }
    )
    item = response.get("Item")
    if item is not None:
        # We have a registered link for this user...
        # This lambda function should only be triggered if the user has a LINK that is currently not expired and still PENDING
        event_time = event.get('Records', []).get('eventTime')
        event_datetime = datetime.fromisofromat(event_time).timestamp()
        if item.get("status") == "PENDING" and item.get("expiresIn") > event_datetime:
            table.update_item(
                Key = {
                    'HK': user_identity,
                    'SK': "Link"
                },
                UpdateExpression='SET #s = :val',
                ExpressionAttributeNames={'#s': "status"},
                ExpressionAttributeValues={':val': 'USED'}
            )