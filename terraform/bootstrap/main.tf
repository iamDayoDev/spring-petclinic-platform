module "oidc" {
  source = "./modules/oidc"

  environment           = var.environment
  github_owner          = var.github_owner
  github_repositories   = var.github_repositories
  github_oidc_role_name = var.github_oidc_role_name
  allowed_branches      = var.allowed_branches
  allow_pull_requests   = var.allow_pull_requests
  role_policy_arns      = var.role_policy_arns
}
