// Outputs surfaced to operators (and to the SPA's build via terraform output).

output "api_endpoint" {
  description = "HTTPS endpoint of the HTTP API (used by CloudFront's api-gateway-origin and the SPA's API base URL)."
  value       = aws_apigatewayv2_api.resume_optimizer_api.api_endpoint
}