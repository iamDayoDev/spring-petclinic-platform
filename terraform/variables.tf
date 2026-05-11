variable "aws_region" {
  description = "AWS region where the cluster and Secrets Manager live"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string

}
variable "environment" { 
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
 }
variable "app_namespace" {
  description = "Namespace used by the Petclinic application"
  type        = string
}
variable "node_instance_type" {
  description = "EC2 instance type for the EKS managed node group"
  type        = string
}
variable "node_desired_size" {
  description = "Desired number of nodes in the EKS managed node group"
  type        = number
}
variable "node_min_size" {
  description = "Minimum number of nodes in the EKS managed node group"
  type        = number
}
variable "node_max_size" {
  description = "Maximum number of nodes in the EKS managed node group"
  type        = number
}
variable "domain" {
  description = "Domain name for the application"
  type        = string
}
variable "eso_role_name" {
  description = "Name of the role for External Secrets Operator"
  type        = string
}
variable "alb_role_name" {
  description = "Name of the role for AWS Load Balancer Controller"
  type        = string
}
variable "alb_policy_name" {
  description = "Name of the policy for AWS Load Balancer Controller"
  type        = string
}
variable "cluster_admin_principal_arns" {
  description = "IAM principal ARNs to grant cluster-admin access to EKS via access entries"
  type        = set(string)
}
