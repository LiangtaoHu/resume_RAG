# Serverless Architecture Solution:
- S3 Static Hosting 
- S3 Buckets
- CloudFront
- Cognito User Pools
- API Gateway w/ Lambda Functions
- Bucket Event Lambda Notifications
- AWS Bedrock Agents/Knowledge Bases
- AWS OpenSearch Serverless
- DynamoDB

## Description
This architecture emphasizes managed/serverless AWS services to implement a low-costing solution for a resume optimizer web application. The client will be able to sign up for the service and be able to parse job listings, upload their resumes, and start conversations with AWS Bedrock Agents performing RAG search on the parsed job listings via a OpenSearch Serverless knowledge base. Within the knowledge base, we have a total of one collection with one vector index for all clients to save cost. In order to make sure we do not confuse one job listing for another, each vector has metadata describing the position, company, and user-id who created it. 

## Website
The website is a React SPA hosted via S3 static hosting + CloudFront.
The user will be redirected to the Cognito Hosted UI if they don't have credentials loaded in from their local storage.
All functionality (parse listings, upload resumes via S3 PreSigned URLs, deleting data, and messaging) are called upon by the frontend via an API Gateway that checks for cognito credentials for each request. 

## Backend
DynamoDB is used to keep track which user submitted what listings (defined by Company - Position) and conversation ID. This approach allows the website to present the user with a "Choose 2" system. The user chooses listed resume and a job listing, to create a conversation or continue a past one which is also graphically displayed. Within the same table, we keep track of resumes, listings, and links that the user submits. Conversations are generated/continued by the user. Conversations are kept track of completely with message history and are stored in the Dynamo database. 

A separate S3 bucket is used for resumes. Resumes are stored with the key "/user-id/{upload-time}.pdf". Upon a successful upload to this bucket, we have an S3 Event Notification that will trigger a lambda function to add the new resume data into DynamoDB.

## Authorization
For authorization we use Cognito User Pools to provide us an auth_code which we exchange for identity and access tokens. We handle this on the callback page on the website. The access token is used for authorizing lambda calls by the user via API Gateway's compatiability with Cognito. 