// OpenSearch Serverless Collection as Vector Database
resource "aws_opensearchserverless_collection" "vector_db" {
  name             = "resume-rag-database"
  type             = "VECTORSEARCH"
  description      = "Vector store for job listing contexts and resumes"
}

// Encryption policy, just defines that the resume-rag-database will be encrypted with AWS owned keys
resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "rag-encryption-policy"
  type        = "encryption"
  description = "Encryption policy for vector search collection"

  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/resume-rag-database"]
    }]
    AWSOwnedKey = true
  })
}

// Network policy
// It can be accessed from over the internet? or privately? In this case, we choose over the Internet
resource "aws_opensearchserverless_security_policy" "network" {
  name        = "rag-network-policy"
  type        = "network"
  description = "Public access policy for vector collection endpoints"
  
  policy = jsonencode([
    {
      Description = "Public access policy for vector collection endpoints"
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

// Data Access Policy
// Now that we've defined we can access it over the Internet, who can access it?
// We would want the one Lambda function for parsing job listings and the Bedrock agent
resource "aws_opensearchserverless_access_policy" "data_access" {
  name        = "rag-data-access-policy"
  type        = "data"
  description = "Grants read/write permissions to Lambda execution role and the master Bedrock agent"
  
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
    Principal = [var.parse_listing_role_ARN, aws_iam_role.bedrock_kb_role.ARN]
  }])
}
