variable "REGION_NAME" {
    type = string
    description = "Region name for Bedrock client"
}

variable "AGENT_ID" {
    type = string
    description = "General ID for agent."
}

variable "AGENT_ALIAS_ID" {
    type = string
    description = "ID for Agent. Specific Version in mind"
}

variable "KB_ID" {
    type = string
    description = "ID of Knowledge Base for Bedrock Agent RAG search"
}

variable "DYNAMO_DB_TABLE" {
    type = string
    description = "Name of Dynamo DB Table"
}