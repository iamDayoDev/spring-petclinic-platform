aws_region  = "us-east-1"
environment = "dev"

github_owner = ["Achievers11-DevOps"]
github_repositories = [
  # "petclinic-k8s-platform",
  # "petclinic-microservices",
  "spring-petclinic-microservices",
  "spring-petclinic-platform",
 
]

github_oidc_role_name = "oidc-github-role"

allowed_branches = [
  "main",
  "ft/app-pipeline",
  "ft/app-build"
]

# Broad permissions keep bootstrap simple for the first pass so GitHub Actions
# can run the main Terraform and deployment workflows. Narrow this later if you
# want a least-privilege setup.
role_policy_arns = [
  "arn:aws:iam::aws:policy/AdministratorAccess",
]
