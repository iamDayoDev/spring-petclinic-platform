variable "aws_region" {
  description = "AWS region used for the bootstrap stack"
  type        = string
}

variable "environment" {
  description = "Deployment environment for bootstrap resources"
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
  default     = "oidc-github-role"
}

variable "allowed_branches" {
  description = "Branches allowed to assume the GitHub Actions role"
  type        = set(string)
  default     = ["main"]
}

variable "allow_pull_requests" {
  description = "Whether pull_request runs for this repository can assume the role"
  type        = bool
  default     = true
}

variable "role_policy_arns" {
  description = "Managed IAM policies attached to the GitHub Actions role"
  type        = set(string)
  default     = []
}
