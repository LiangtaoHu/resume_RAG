output "opensearch_url" {
  description = "Vector Database OpenSearch URL"
  value       = aws_opensearchserverless_collection.vector_db.collection_endpoint
}

output "opensearch_arn" {
    description = "Vector Database OpenSearch ARN"
    value       = aws_opensearchserverless_collection.vector_db.arn
}