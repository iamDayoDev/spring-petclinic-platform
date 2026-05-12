variable "environment" {
  description = "Environment tag value applied to bootstrap resources"
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or user that owns the repository"
  type        = string
}

variable "github_repositories" {
  description = "GitHub repository names allowed to assume the role"
  type        = set(string)
}

variable "github_oidc_role_name" {
  description = "IAM role name assumed by GitHub Actions through OIDC"
  type        = string
}

variable "allowed_branches" {
  description = "Branches allowed to assume the GitHub Actions role"
  type        = set(string)
}

variable "allow_pull_requests" {
  description = "Whether pull_request runs for the allowed repositories can assume the role"
  type        = bool
}

variable "role_policy_arns" {
  description = "Managed IAM policies attached to the GitHub Actions role"
  type        = set(string)
}
