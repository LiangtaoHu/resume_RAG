data "aws_caller_identity" "current" {}
// OpenSearch Serverless Collection as Vector Database
resource "aws_opensearchserverless_collection" "vector_db" {
  name             = "resume-rag-database"
  type             = "VECTORSEARCH"
  description      = "Vector store for job listing contexts and resumes"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption
  ]
}

// Encryption policy, just defines that the resume-rag-database will be encrypted with AWS owned keys
resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "rag-encryption-policy"
  type        = "encryption"
  description = "Encryption policy for vector search collection"

  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/resume-rag-database*"]
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
            "collection/resume-rag-database"
          ]
        }, 
        {
          ResourceType = "dashboard"
          Resource = [
            "collection/resume-rag-database"
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
      Resource     = ["index/resume-rag-database/*"]
      Permission   = [
        "aoss:CreateIndex",
        "aoss:DescribeIndex",
        "aoss:ReadDocument",
        "aoss:WriteDocument",
        "aoss:DeleteIndex",
        "aoss:UpdateIndex"
      ]
    }, 
    {
      ResourceType = "collection"
      Resource     = ["collection/resume-rag-database"]
      Permission   = [
        "aoss:CreateCollectionItems",
        "aoss:UpdateCollectionItems",
        "aoss:DescribeCollectionItems"
      ]
    }]
    Principal = [aws_iam_role.lambda_parse_listing_role.arn, aws_iam_role.bedrock_kb_role.arn, data.aws_caller_identity.current.arn]
  }])
}

resource "null_resource" "resume_rag_index" {
  # Recreate if the mapping definition or collection endpoint changes
  triggers = {
    mapping_hash = sha256(jsonencode({
      properties = {
        "bedrock-vector" = {
          type      = "knn_vector"
          dimension = 1024
          method = {
            name       = "hnsw"
            engine     = "faiss"
            space_type = "l2"
            parameters = {
              m               = 16
              ef_construction = 512
            }
          }
        }
        "bedrock-text"     = { type = "text" }
        "bedrock-metadata" = { type = "text" }
      }
    }))
    collection_endpoint = aws_opensearchserverless_collection.vector_db.collection_endpoint
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      RESPONSE=$(awscurl --service aoss --region us-east-1 -X PUT \
        "${aws_opensearchserverless_collection.vector_db.collection_endpoint}/resume-rag-index" \
        -H "Content-Type: application/json" \
        -d '{
          "settings": {
            "index.knn": true
          },
          "mappings": {
            "properties": {
              "bedrock-vector": {
                "type": "knn_vector",
                "dimension": 1024,
                "method": {
                  "name": "hnsw",
                  "engine": "faiss",
                  "space_type": "l2",
                  "parameters": { "m": 16, "ef_construction": 512 }
                }
              },
              "bedrock-text": { "type": "text" },
              "bedrock-metadata": { "type": "text" }
            }
          }
        }')
      echo "$RESPONSE"
      if echo "$RESPONSE" | grep -q '"error"'; then
        echo "Index creation failed: $RESPONSE"
        exit 1
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Note: manually delete OpenSearch index resume-rag-index if needed'"
  }

  depends_on = [
    aws_opensearchserverless_access_policy.data_access,
    aws_opensearchserverless_collection.vector_db
  ]
}