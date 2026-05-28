import os
import json
import base64
import boto3
import hashlib
from datetime import datetime

client = boto3.client("s3")

def hash_file_object(file_bytes):
    hash_md5 = hashlib.md5()
    hash_md5.update(file_bytes)
    # S3 must accept a ContentMD5 of a base 64 encoded hash
    return base64.b64encode(hash_md5.digest()).decode('utf-8')

def lambda_handler(event, context):
    try:
        # The event would result from an incoming HTTP Post request that has the document in the body
        # Check if the file is a correct PDF file first
        if event["headers"]["content-type"] != "application/pdf":
            return {
                "statusCode": 400,
                "body": json.dumps({"Error: Resume must be a PDF file."})
            }
        
        # Should be the original pdf
        pdf_bytes = base64.b64decode(event["body"])

        # When putting an object to the S3 bucket, we should specify:
        # The name of the bucket or specific bucket ARN
        # The name of the resume file which is a concatenation of the user and time
        #   - User should be a header value?
        # Encryption?

        object_key = event["headers"]["username"]
        now = datetime.now()
        object_key = object_key + "-" + now.strftime("%Y-%m-%d-%H-%M-%S") + ".pdf"
        hash_md5 = hash_file_object(pdf_bytes)

        client.put_object(
            Bucket = os.environ.get("RESUME_BUCKET_NAME"),
            Body = pdf_bytes,
            Key = object_key,
            ContentMD5 = hash_md5,
            ServerSideEncryption = "AES256"
        )

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "message": "Resume successfully uploaded to S3.",
                "file_key": object_key
            })
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"Error": "Couldn't push resume to S3."})
        }