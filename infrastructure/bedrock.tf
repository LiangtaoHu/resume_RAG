data "aws_partition" "curr_partition" {}

/* ========================================================================== */
/* Bedrock Knowledge Base                                                     */
/* ========================================================================== */
resource "aws_iam_role" "bedrock_kb_role" {
    name = "bedrock-kb-exec-role"
    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
    }]
  })
}

data "aws_iam_policy_document" "bedrock_kb_statement" {
    // Access to OpenSearch collection
    statement {
        sid = "OpenSearchAccess"
        effect = "Allow"
        actions = ["aoss:APIAccessAll"]
        resources = [aws_opensearchserverless_collection.vector_db.arn]
    }
    // Convert User Request to Embeddings during RAG
    statement {
        sid = "BedrockEmbeddingAccess"
        effect = "Allow"
        actions = ["bedrock:InvokeModel"]
        resources = ["arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"]
    }
}

resource "aws_iam_policy" "bedrock_kb_policy" {
  name = "bedrock-kb-exec-permissions"
  policy = data.aws_iam_policy_document.bedrock_kb_statement.json
}

resource "aws_iam_role_policy_attachment" "bedrock_kb_attachment" {
  role = aws_iam_role.bedrock_kb_role.name
  policy_arn =  aws_iam_policy.bedrock_kb_policy.arn
}

resource "aws_bedrockagent_knowledge_base" "rag_kb" {
    name = "resume-knowledge-base"
    description = "This will connect all the files needed for resume optimization"
    role_arn = aws_iam_role.bedrock_kb_role.arn

    knowledge_base_configuration {
      type = "VECTOR"
      vector_knowledge_base_configuration {
        embedding_model_arn = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
      }
    }

    storage_configuration {
      type = "OPENSEARCH_SERVERLESS"
      opensearch_serverless_configuration {
        collection_arn = aws_opensearchserverless_collection.vector_db.arn
        vector_index_name = "resume-rag-index"
        field_mapping {
          vector_field = "bedrock-vector"
          text_field = "bedrock-text"
          metadata_field = "bedrock-metadata"
        }
      }
    }
  depends_on = [null_resource.resume_rag_index]
}

/* ========================================================================== */
/* Bedrock Agent                                                              */
/* ========================================================================== */
resource "aws_iam_role" "bedrock_agent_role" {
    name = "bedrock-agent-exec-role"
    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
    }]
  })
}

data "aws_iam_policy_document" "bedrock_agent_statement" {
    statement {
      sid = "InvokeFoundationalModel"
      actions = ["bedrock:InvokeModel"]
      resources = ["arn:${data.aws_partition.curr_partition.partition}:bedrock:${data.aws_region.curr_region.region}::foundation-model/anthropic.claude-v2"]
    }
    statement {
      sid = "AllowAgentToQueryKB"
      actions = ["bedrock:Retrieve"]
      resources = [aws_bedrockagent_knowledge_base.rag_kb.arn]
    }
}

resource "aws_iam_policy" "bedrock_agent_policy" {
  name = "bedrock-agent-exec-policy"
  policy = data.aws_iam_policy_document.bedrock_agent_statement.json
}

resource "aws_iam_role_policy_attachment" "bedrock_agent_attachment" {
  role = aws_iam_role.bedrock_agent_role.name
  policy_arn =  aws_iam_policy.bedrock_agent_policy.arn
}

resource "aws_bedrockagent_agent" "resume_agent" {
  agent_name                  = "resume-optimizer"
  agent_resource_role_arn     = aws_iam_role.bedrock_agent_role.arn
  idle_session_ttl_in_seconds = 300
  foundation_model            = "amazon.nova-pro-v1:0"
  instruction                 = "You are a professional at optimizing CS resumes to job applications. You will have access to a vector database which will contain the most important information about a job listing and a user resume. Your job is to edit the resume to increase the chance of being hired."

  memory_configuration {
    enabled_memory_types = ["SESSION_SUMMARY"]
    session_summary_configuration {
      max_recent_sessions = 10
    }
    storage_days = 30
  }
}

// Linking the two together, KB and Agent
resource "aws_bedrockagent_agent_knowledge_base_association" "bedrock_kb_agent_association" {
  agent_id = aws_bedrockagent_agent.resume_agent.id
  knowledge_base_id = aws_bedrockagent_knowledge_base.rag_kb.id
  description = "Use this knowledge base to access and retrieve specific job listings and their requirements"
  knowledge_base_state = "ENABLED"
}