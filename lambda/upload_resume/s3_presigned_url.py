import os
import json
import boto3
from datetime import datetime
from botocore.config import Config

# TODO: Get rid of spoofing possiblity by validating JWT x-amzn-oidc-data header

REGION_NAME = os.environ['REGION_NAME']
EXPIRATION_TIME = os.environ['EXPIRATION_TIME']
RESUME_BUCKET = os.environ['RESUME_BUCKET']

s3_client = boto3.client('s3', region_name=REGION_NAME, config=Config(
    signature_version = 's3v4',
    s3 = {'addressing_style': 'virtual'}
))

def handler(event, context):
    now = datetime.now()
    time_formatted =  now.strftime("%Y-%m-%d-%H-%M-%S")

    raw_headers = event.get("headers", {})
    headers = {k.lower(): v for k, v in raw_headers.items()}
    user_identity = headers.get("x-amzn-oidc-identity")

    if not user_identity:
        return {
            "statusCode": 401,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Unauthorized: Missing identity header from ALB"})
        }

    key = f"resumes/{user_identity}/{time_formatted}.pdf"

    try:
        url = s3_client.generate_presigned_url('put_object', Params={
                "Bucket": RESUME_BUCKET,
                "Key": key,
                "ContentType": "application/pdf"
            },
            ExpiresIn=EXPIRATION_TIME
        )

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "link": url
            })
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }