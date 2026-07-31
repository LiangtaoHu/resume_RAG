import os 
import boto3
from datetime import datetime
import urllib.parse
import pymupdf4llm

'''
This defines the lambda function that is called when an object is successfully added into the resume folder.
It contacts the dynamo database and changes the s3 presigned URL saved from a PENDING to a COMPLETE status.
This is to ensure that each link can only be used once per expiration time period or equivalently one upload per expiration time period.
'''

REGION_NAME = os.environ['REGION_NAME']
DYNAMO_DB_TABLE = os.environ["DYNAMO_DB_TABLE"]

s3_client = boto3.client('s3')
dynamo_client = boto3.resource("dynamodb", region_name=REGION_NAME)
table = dynamo_client.Table(DYNAMO_DB_TABLE)

def get_path_values(event):
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    # Split between "/" delimiter, first portion will be user identity the second will be the time
    file_name, user_identity = key.split("/")[-1], key.split("/")[0]
    return key, file_name, user_identity

def handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key, file_name, user_identity = get_path_values(event)
    # Updating Link
    response = table.get_item(
        Key = {
            'HK': "USER#" + user_identity,
            'SK': "LINK"
        }
    )
    item = response.get("Item")
    if item is not None:
        records = event.get('Records', [])
        if records:
            event_time = records[0].get('eventTime')
            clean_event_time = event_time.replace('Z', '+00:00')
            event_datetime = datetime.fromisoformat(clean_event_time).timestamp()
            
            # Check link status and expiration criteria
            if item.get("status") == "PENDING" and item.get("expiresIn") > event_datetime:
                table.update_item(
                    Key = {
                        'HK': "USER#" + user_identity,
                        'SK': "LINK"
                    },
                    UpdateExpression='SET #s = :val',
                    ExpressionAttributeNames={'#s': "status"},
                    ExpressionAttributeValues={':val': 'USED'}
                )
    # Updating resume
    local_path = '/tmp/' + file_name 
    
    s3_client.download_file(bucket, key, local_path)
    md = pymupdf4llm.to_markdown(local_path)
    table.put_item(
        Item = {
            'HK': f'USER#{user_identity}',
            'SK': f'RESUME#{file_name.split(".")[0]}',
            'S3Location': key,
            'cachedText': md
        }
    )
    if os.path.exists(local_path):
        os.remove(local_path)