variable "aws_region" { default = "us-east-1" }
variable "cluster_name" { default = "petclinic-eks" }
variable "environment" { default = "production" }
variable "app_namespace" {
  description = "Namespace used by the Petclinic application"
  type        = string
}
variable "node_instance_type" {
  description = "EC2 instance type for the EKS managed node group"
  type        = string
  default     = "t3.small"
}
variable "node_desired_size" {
  description = "Desired number of nodes in the EKS managed node group"
  type        = number
  default     = 2
}
variable "node_min_size" {
  description = "Minimum number of nodes in the EKS managed node group"
  type        = number
  default     = 1
}
variable "node_max_size" {
  description = "Maximum number of nodes in the EKS managed node group"
  type        = number
  default     = 3
}
variable "domain" { default = "eta-oko.com" }
variable "eso_role_name" { default = "petclinic-eso-role" }
variable "alb_role_name" { default = "petclinic-alb-role" }
variable "alb_policy_name" { default = "AWSLoadBalancerControllerIAMPolicy" }
variable "cluster_admin_principal_arns" {
  description = "IAM principal ARNs to grant cluster-admin access to EKS via access entries"
  type        = set(string)
  default     = ["arn:aws:iam::979779072306:user/Aderinto"]
}
