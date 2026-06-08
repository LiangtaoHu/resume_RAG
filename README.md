This architecture makes use of:
    - An ALB w/ Cognito targetting three groups
        - Group #1: 
            - Name: /upload_resume 
            - Allows user to upload resumes to optimize in advance by returning an S3 Presigned URL
            - Published to an S3 server with the key being /resumes/{USER_ID}/{TIME}.pdf
        - Group #2:
            - Name: /parse_listing
            - Allows user to parse job listings in advance and push to user-specific vector index in OpenSearch Serverless
        - Group #3:
            - Name: /converse
            - Allows user to connect to an EC2 instance
            - EC2 instance holds both static website files and has backend functionality
            - User can then use the website to select/upload a resume they want to optimize and parse/choose a job listing
            - User can "chat" with the EC2 instance by invoking a Bedrock Agent with a specified vector-index as a knowledge base
            - Resumes can then be stored back into S3 service bucket
    - A VPC that contains:
        - The ASG spanning 3 AZs in the us-east-1 region
            - Security groups to limit inwards communication to EC2 instances to only the ALB based on sec group id
            - Scaling policies should be based on CPU usage
            - Launch template wasn't made
        - VPC Endpoint for AWS Bedrock
            - Security groups to limit communication to only EC2 instances based on sec group id
    - OpenSearch Serverless Collection
        - Holds multiple user vector indexes
        - Data policy limiting to only bedrock and Lambda
        - Network policy accessible from public
    - Cognito User Pool/Domain/Client
        - Makes use of email and/or phone number for recovery/verification/MFA
    - Bedrock Agent
        - Used for RAG resume optimization
    - IAM roles in order to allow services like Lambda to use other services

Issues of Concern:
    - EC2 instances don't need to hold onto static website pages when we can use S3 w/ Static Hosting & CloudFront
    - Having an ASG w/ EC2 instances is expensive in general as I don't have a userbase or will have a big one in the future
    
Solution:
    - Fully serverless/available arch. with:
        - S3 Static Hosting w/ CloudFront (Default path)
        - Cognito User Pools
        - Lambda functions triggered based on request path
            - /parse_listing
            - /upload_resume
            - /chat