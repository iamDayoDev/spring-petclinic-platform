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

output "monitoring_namespace" {
  description = "Namespace where kube-prometheus-stack is installed"
  value       = module.addons.monitoring_namespace
}

output "monitoring_release_name" {
  description = "Helm release name for kube-prometheus-stack"
  value       = module.addons.monitoring_release_name
}

output "grafana_service_name" {
  description = "Kubernetes service name for Grafana"
  value       = module.addons.grafana_service_name
}

output "prometheus_service_name" {
  description = "Kubernetes service name for Prometheus"
  value       = module.addons.prometheus_service_name
}

output "grafana_port_forward_command" {
  description = "Command to access Grafana locally after the monitoring stack is installed"
  value       = "kubectl port-forward svc/${module.addons.grafana_service_name} 3000:80 -n ${module.addons.monitoring_namespace}"
}

output "prometheus_port_forward_command" {
  description = "Command to access Prometheus locally after the monitoring stack is installed"
  value       = "kubectl port-forward svc/${module.addons.prometheus_service_name} 9090:9090 -n ${module.addons.monitoring_namespace}"
}

output "argocd_namespace" {
  description = "Namespace where Argo CD is installed"
  value       = module.addons.argocd_namespace
}

output "argocd_release_name" {
  description = "Helm release name for Argo CD"
  value       = module.addons.argocd_release_name
}

output "argocd_server_service_name" {
  description = "Kubernetes service name for the Argo CD API server"
  value       = module.addons.argocd_server_service_name
}

output "argocd_port_forward_command" {
  description = "Command to access Argo CD locally after the addon is installed"
  value       = "kubectl port-forward svc/${module.addons.argocd_server_service_name} 8080:80 -n ${module.addons.argocd_namespace}"
}

output "argocd_admin_password_command" {
  description = "Command to read the initial Argo CD admin password after the addon is installed"
  value       = "kubectl -n ${module.addons.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
}

output "external_dns_release_name" {
  description = "Helm release name for ExternalDNS"
  value       = module.addons.external_dns_release_name
}

output "configure_kubectl" {
  description = "Command to configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "app_domain" {
  description = "Public hostname exposed for the Petclinic entrypoint"
  value       = var.domain
}

output "route53_zone_id" {
  description = "Route 53 public hosted zone ID used for the application domain"
  value       = module.route53.hosted_zone_id
}

output "app_certificate_arn" {
  description = "ACM certificate ARN managed for the application domain"
  value       = module.route53.certificate_arn
}

output "external_dns_role_name" {
  description = "IAM role name for ExternalDNS"
  value       = module.iam.external_dns_role_name
}

output "external_dns_role_arn" {
  description = "IAM role ARN for ExternalDNS"
  value       = module.iam.external_dns_role_arn
}
