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
