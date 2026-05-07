variable "services" {
  description = "Set of service names for which ECR repositories will be created"
  type        = set(string)
  default = [
    "config-server",
    "discovery-server",
    "api-gateway",
    "customers-service",
    "vets-service",
    "visits-service",
    "admin-server",
    "genai-service",
  ]
}
