data "aws_partition" "curr_partition" {}
data "aws_region" "curr_region" {}

data "aws_iam_policy_document" "bedrock_kb_role_policy" {
    statement {
        effect = "Allow"
        actions = ["s3:GetObject", "s3:ListBucket"]
        resources = [var.bucket_name]
    }

    statement {
        effect = "Allow"
        actions = ["aoss:APIAccessService"]
        resources = [aws_opensearchserverless_collection.vector_db.arn]
    }

    statement {
        effect = "Allow"
        actions = ["bedrock:InvokeModel"]
        resources = ["arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"]
    }
}

resource "aws_iam_role" "bedrock_kb_role" {
    name = "kb-exec-role"
    assume_role_policy = data.aws_iam_policy_document.bedrock_kb_role_policy.json
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
        vector_index_name = "resume-rag-database"
        field_mapping {
          vector_field = "bedrock-vector"
          text_field = "bedrock-text"
          metadata_field = "bedrock-metadata"
        }
      }
    }
}

data "aws_iam_policy_document" "agent_trust" {
    statement {
      actions = ["sts:AssumeRole"]
      principals {
        identifiers = ["bedrock.amazonaws.com"]
        type = "Service"
      }
    }
}

resource "aws_iam_role" "bedrock_agent_role" {
    name = "bedrock-agent-exec-role"
    assume_role_policy = data.aws_iam_policy_document.agent_trust.json
}

data "aws_iam_policy_document" "agent_permissions" {
    statement {
      actions = ["bedrock:InvokeModel"]
      resources = ["arn:${data.aws_partition.curr_partition.partition}:bedrock:${data.aws_region.curr_region.region}::foundation-model/anthropic.claude-v2"]
    }
}

resource "aws_iam_role_policy" "agent_permission_attachment" {
  policy = data.aws_iam_policy_document.agent_permissions.json
  role   = aws_iam_role.bedrock_agent_role.id
}

resource "aws_bedrockagent_agent" "resume-agent" {
  agent_name                  = "resume-optimizer"
  agent_resource_role_arn     = aws_iam_role.bedrock_agent_role.arn
  idle_session_ttl_in_seconds = 300
  foundation_model            = "anthropic.claude-v2"
  instruction                 = "You are a professional at optimizing CS resumes to job applications. You will have access to a vector database which will contain the most important information about a job listing and a user resume. Your job is to edit the resume to increase the chance of being hired."

  memory_configuration {
    enabled_memory_types = ["SESSION_SUMMARY"]

    session_summary_configuration {
      max_recent_sessions = 10
    }
    storage_days = 30
  }
}