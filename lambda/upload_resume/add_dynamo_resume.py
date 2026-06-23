import os
import boto3
import urllib
import pymupdf4llm

'''
This defines a Lambda function that triggers when a resume is uploaded to the resume bucket.
This function saves a resume entry to the DynamoDB table with the most important attribute being the cachedText. 
Because resumes have some sort of structure, it would be best to preserve it so that some information belonging to one section doesn't affect the other.
Thankfully, we don't have to make the code for that. 
'''

DYNAMO_DB_TABLE = os.environ["DYNAMO_DB_TABLE"]

s3_client = boto3.client('s3')
dynamo_client = boto3.resource('dynamodb')
dynamo_table = dynamo_client.Table(DYNAMO_DB_TABLE)

def handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    file_name = key.split("/")[-1]
    local_path = '/tmp/' + file_name 
    s3_client.download_file(bucket, key, local_path)
    
    json_format = pymupdf4llm.to_json(local_path)