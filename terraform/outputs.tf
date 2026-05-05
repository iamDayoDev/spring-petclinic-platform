output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint of the EKS cluster"
  value       = module.eks.cluster_endpoint
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

output "configure_kubectl" {
  description = "Command to configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
