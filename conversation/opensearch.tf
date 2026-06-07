// OpenSearch Serverless Collection as Vector Database
resource "aws_opensearchserverless_collection" "vector_db" {
  name             = "resume-rag-database"
  type             = "VECTORSEARCH" # Crucial: Allocates specific vector indexing infrastructure
  description      = "Vector store for job listing contexts and resumes"
}

// OpenSearch Security Encryption Policy
resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "rag-encryption-policy"
  type        = "encryption"
  description = "Encryption policy for vector search collection"
  
  # AWS manages encryption using their default keys
  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/resume-rag-database"]
    }]
    AWSOwnedKey = true
  })
}

// OpenSearch Network Access Policy (Public endpoint configuration)
resource "aws_opensearchserverless_security_policy" "network" {
  name        = "rag-network-policy"
  type        = "network"
  description = "public access policy for vector collection endpoints"
  
  policy = jsonencode([
    {
      Description = "public access policy for vector collection endpoints"
      Rules = [
        {
          ResourceType = "collection"
          Resource = [
            "collection/resume-rag-db"
          ]
        }, 
        {
          ResourceType = "dashboard"
          Resource = [
            "collection/resume-rag-db"
          ]
        }
      ],
      "AllowFromPublic": true
    }
  ])
}

// Data Access Policy: Grant permissions to your Lambda function's IAM Role
resource "aws_opensearchserverless_access_policy" "data_access" {
  name        = "rag-data-access-policy"
  type        = "data"
  description = "Grants read/write permissions to Lambda execution role and Bedrock"
  
  policy = jsonencode([
    {
    Rules = [
      {
      ResourceType = "index"
      Resource     = ["index/resume-rag-db/*"]
      Permission   = [
        "aoss:CreateIndex",
        "aoss:DescribeIndex",
        "aoss:ReadDocument",
        "aoss:WriteDocument"
      ]
    }, 
    {
      ResourceType = "collection"
      Resource     = ["collection/resume-rag-db"]
      Permission   = [
        "aoss:CreateCollectionItems",
        "aoss:UpdateCollectionItems",
        "aoss:DescribeCollectionItems"
      ]
    }]
    Principal = [var.lambda_role, aws_iam_role.bedrock_kb_role.arn]
  }])
}
