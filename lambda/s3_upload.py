import json

def lambda_handler(event, context):
    try:
        # The event would result from an incoming HTTP Post request that has the document in the body
        # Check if the file is a correct PDF file first
        if event["headers"]["content-type"] != "application/pdf":
            raise Exception("Invalid File Format. Must be PDF.")

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "message": "Resume successfully uploaded to S3.",
            })
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }