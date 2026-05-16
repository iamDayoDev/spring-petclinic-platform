variable "aws_region" {
  description = "AWS region where the cluster and Secrets Manager live"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID used by the AWS Load Balancer Controller"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "app_namespace" {
  description = "Namespace used by the Petclinic application"
  type        = string
}

variable "monitoring_namespace" {
  description = "Namespace where the monitoring stack runs"
  type        = string
}

variable "monitoring_grafana_service_type" {
  description = "Kubernetes service type for Grafana in the monitoring stack"
  type        = string
}

variable "monitoring_zipkin_service_type" {
  description = "Kubernetes service type for Zipkin in the monitoring stack"
  type        = string
}

variable "argocd_namespace" {
  description = "Namespace where Argo CD runs"
  type        = string
}

variable "argocd_server_service_type" {
  description = "Kubernetes service type for the Argo CD API server"
  type        = string
}

variable "cluster_secret_store_name" {
  description = "ClusterSecretStore name used by application ExternalSecrets"
  type        = string
}

variable "eso_namespace" {
  description = "Namespace where External Secrets Operator runs"
  type        = string
}

variable "eso_service_account_name" {
  description = "Service account name used by External Secrets Operator"
  type        = string
}

variable "eso_role_arn" {
  description = "IRSA role ARN for External Secrets Operator"
  type        = string
}

variable "alb_namespace" {
  description = "Namespace where the AWS Load Balancer Controller runs"
  type        = string
}

variable "alb_service_account_name" {
  description = "Service account name used by the AWS Load Balancer Controller"
  type        = string
}

variable "alb_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller"
  type        = string
}

variable "external_dns_namespace" {
  description = "Namespace where ExternalDNS runs"
  type        = string
}

variable "external_dns_service_account_name" {
  description = "Service account name used by ExternalDNS"
  type        = string
}

variable "external_dns_role_arn" {
  description = "IRSA role ARN for ExternalDNS"
  type        = string
}

variable "hosted_zone_name" {
  description = "Public Route 53 hosted zone name managed by ExternalDNS"
  type        = string
}
