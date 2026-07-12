// OpenSearch Serverless collection used as the Bedrock KB vector store.
//
// Note: there is a known mismatch between this collection's vector index name
// ("resume-rag-database" below) and the index that parse_listing writes to
// (f"{sub.lower()}-job-listings" in lambda/parse_listing/lambda_scraper.py).
// KB retrieval will return nothing until the scraper is updated.

resource "aws_opensearchserverless_collection" "vector_db" {
  name        = "resume-rag-database"
  type        = "VECTORSEARCH"
  description = "Vector store for job listing contexts and resumes"
}

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
          Resource     = ["collection/resume-rag-db"]
        },
        {
          ResourceType = "dashboard"
          Resource     = ["collection/resume-rag-db"]
        }
      ],
      "AllowFromPublic" = true
    }
  ])
}

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
        }
      ]
      Principal = [var.parse_listing_role_ARN, aws_iam_role.bedrock_kb_role.arn]
    }
  ])
}