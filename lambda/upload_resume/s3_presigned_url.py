import os
import json
import boto3
from datetime import datetime
from botocore.config import Config

# Should have idtoken to represent identity already. Plus, its already authenticated.

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

    cookies = {}
    if "cookie" in headers:
        # Loop through all the cookies
        for cookie in headers["cookie"]:
            # We are mainly interested in the value as the key for each is just "cookie"
            # The value can be multi-cookie per actual cookie, with a separator of ";"
            cookie_string = cookie.get("value", "")
            for cookie_instance in cookie_string.split(";"):
                # We split again on the equals sign
                key, value = cookie_instance.split("=", 1)
                cookies[key.strip()] = value.strip()
    user_identity = cookies.get("idToken")
    if not user_identity:
        return {
            "statusCode": 401,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Unauthorized: Missing idToken"})
        }

    key = f"{user_identity.lower()}/{time_formatted}.pdf"

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