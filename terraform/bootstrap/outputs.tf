output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role"
  value       = module.oidc.role_arn
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions IAM role"
  value       = module.oidc.role_name
}
