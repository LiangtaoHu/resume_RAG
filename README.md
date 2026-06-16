# Serverless Architecture Solution:
- S3 Static Hosting 
- S3 Buckets
- CloudFront
- Cognito User Pools
- Lambda Functions (Lambda Origins and Lambda@Edge)
- AWS Bedrock Agents/Knowledge Bases
- AWS OpenSearch Serverless
- DynamoDB

## Description
This architecture emphasizes managed/serverless AWS services to implement a low-costing solution for a resume optimizer web application. The client will be able to sign up for the service and be able to parse job listings, upload their resumes, and start conversations with AWS Bedrock Agents performing RAG search on the parsed job listings via a OpenSearch Serverless knowledge base. Within the knowledge base, we have a total of one collection with one vector index for all clients to save cost. In order to make sure we do not confuse one job listing for another, each vector has metadata describing the position, company, and user-id who created it. 

## Website
The website is hosted via S3 static hosting + CloudFront.
All functionality (parse listings, upload resumes via S3 PreSigned URLs, and messaging) is implemented with Cloudfront Lambda Function URLs which the website calls with Javascript.

DynamoDB is used to keep track which user submitted what listings (defined by Company - Position) and conversation ID. This approach allows the website to present the user with a "Choose 2" system. The user chooses listed resume and a job listing, to create a conversation or continue a past one which is also graphically displayed.

A separate S3 bucket is used for resumes for development purposes. Resumes are stored with the key "/user-id/{upload-time}.pdf"

## Authorization
In order to make sure the service is only used by our users, the architecture uses Lambda@Edge functions to check before hitting landing pages that the user has a valid idToken and/or refreshToken. If they do not, we either redirect them to the Cognito Hosted UI to recieve an auth code and exchange for tokens or we gain new tokens with the refreshToken. This design was heavily inspired by [Authorization@Edge](https://github.com/aws-samples/cloudfront-authorization-at-edge). 

## Downsides
The main downsides with this approach are the main downsides with Lambda functions in general. In this case, there's a need to work around the 15 minute time period and the size of the function. What's worse is that Lambda@Edge has heavier restrictions with the additional restriction of on environmental variables. In order to get around the new problem, we bypass it by creating a local_file within lambda/authorization subfolder with Terraform with those values. This way our Lambda@Edge functions can retrieve them with a simple local import.