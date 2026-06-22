import os
import json
import boto3
import time
from datetime import datetime
from botocore.config import Config

# Should have idtoken to represent identity already. Plus, its already authenticated.

REGION_NAME = os.environ['REGION_NAME']
EXPIRATION_TIME = int(os.environ['EXPIRATION_TIME'])
RESUME_BUCKET = os.environ['RESUME_BUCKET']

s3_client = boto3.client('s3', region_name=REGION_NAME, config=Config(
    signature_version = 's3v4',
    s3 = {'addressing_style': 'virtual'}
))

dynamo_client = boto3.resource("dynamodb", region_name=REGION_NAME)
table = dynamo_client.Table("res-optimizer-user-data")

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
        response = table.get_item(
            Key = {
                'HK': user_identity,
                'SK': "Link"
            }
        )
        item = response.get("Item")
        if item is not None:
            '''
                BufferTime is to make sure we don't give a link that's about to expire and so it doesn't work.
                We give 10 extra seconds. If the expiration time is less than that time of upload, we check the elif (fails) then generate a new link and return.
                The elif statement is used to make sure all links are used only once so one upload per expiration time window (which is noted via the status value).
                So if we already used the link once (uploaded once) in our time window, we have to wait till the link actually expires (exp window ends) to make another upload.
            '''
            bufferTime = 10 
            if item.get("expiresIn") > (int(time.time()) + bufferTime) and item.get("status") == "PENDING":
                return {
                    "statusCode": 200,
                    "headers": {"Content-Type": "application/json"},
                    "body": json.dumps({
                        "link": item.get("url"),
                        "fields": item.get("fields")
                    })
                }
            elif item.get("status") == "USED" and item.get("expiresIn") > int(time.time()):
                return {
                    "statusCode": 403,
                    "headers" : {"Content-Type": "application/json"},
                    "body": json.dumps({
                        "error": f"You can only upload one resume per {EXPIRATION_TIME} seconds"
                    })
                }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(e)})
        }
    
    key = f"{user_identity.lower()}/{time_formatted}.pdf"

    try:
        post = s3_client.generate_presigned_post(
            Bucket=RESUME_BUCKET,
            Key=key,
            Fields = {
                "Content-Type": "application/pdf",
                "If-None-Match": "*"
            },
            Conditions = [
                ["content-length-range", 1, 10485760], # 10MB max
                {"Content-Type": "application/pdf"},
                ["eq", "$If-None-Match", "*"]
            ],
            ExpiresIn=EXPIRATION_TIME
        )

        table.put_item(
            Item = {
                'HK': user_identity,
                'SK': "Link",
                "url": post.get("url"),
                "fields": post.get("fields"),
                "status": "PENDING",
                "expiresIn": int(time.time()) + EXPIRATION_TIME
            }
        )

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "link": post.get("url"),
                "fields": post.get("fields")
            })
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": str(e)})
        }