output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider used for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the EKS OIDC provider used for IRSA"
  value       = module.eks.oidc_provider_url
}

output "ecr_repository_urls" {
  description = "Map of service name to ECR repository URL"
  value       = module.ecr.repository_urls
}

output "db_endpoint" {
  description = "Connection endpoint of the RDS MySQL instance"
  value       = module.rds.db_endpoint
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding DB credentials"
  value       = module.rds.secret_arn
}

output "eso_role_name" {
  description = "IAM role name for External Secrets Operator"
  value       = module.iam.eso_role_name
}

output "eso_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = module.iam.eso_role_arn
}

output "alb_role_name" {
  description = "IAM role name for the AWS Load Balancer Controller"
  value       = module.iam.alb_role_name
}

output "alb_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  value       = module.iam.alb_role_arn
}

output "alb_policy_arn" {
  description = "Customer-managed IAM policy ARN for the AWS Load Balancer Controller"
  value       = module.iam.alb_policy_arn
}

output "app_namespace" {
  description = "Namespace created for the Petclinic application"
  value       = module.addons.app_namespace
}

output "cluster_secret_store_name" {
  description = "ClusterSecretStore name used by application ExternalSecrets"
  value       = module.addons.cluster_secret_store_name
}

output "configure_kubectl" {
  description = "Command to configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
