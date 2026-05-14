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

variable "repository_prefix" {
  description = "Prefix applied to each ECR repository name"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment tag applied to ECR resources"
  type        = string
}
