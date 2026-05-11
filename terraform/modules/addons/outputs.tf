output "app_namespace" {
  description = "Namespace created for the Petclinic application"
  value       = kubernetes_namespace_v1.app.metadata[0].name
}

output "cluster_secret_store_name" {
  description = "ClusterSecretStore name used by application ExternalSecrets"
  value       = var.cluster_secret_store_name
}

output "external_secrets_release_name" {
  description = "Helm release name for External Secrets Operator"
  value       = helm_release.external_secrets.name
}

output "alb_controller_release_name" {
  description = "Helm release name for the AWS Load Balancer Controller"
  value       = helm_release.aws_load_balancer_controller.name
}
