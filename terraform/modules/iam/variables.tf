variable "environment" {
  description = "Environment tag value applied to IAM resources"
  type        = string
  default     = "production"
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider used for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider used for IRSA"
  type        = string
}

variable "eso_role_name" {
  description = "IAM role name for External Secrets Operator"
  type        = string
  default     = "petclinic-eso-role"
}

variable "eso_namespace" {
  description = "Namespace of the External Secrets service account"
  type        = string
  default     = "external-secrets"
}

variable "eso_service_account_name" {
  description = "Service account name used by External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

variable "eso_policy_arn" {
  description = "Managed policy attached to the External Secrets IAM role"
  type        = string
  default     = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

variable "alb_role_name" {
  description = "IAM role name for the AWS Load Balancer Controller"
  type        = string
  default     = "petclinic-alb-role"
}

variable "alb_namespace" {
  description = "Namespace of the AWS Load Balancer Controller service account"
  type        = string
  default     = "kube-system"
}

variable "alb_service_account_name" {
  description = "Service account name used by the AWS Load Balancer Controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "alb_policy_name" {
  description = "Customer-managed policy name for the AWS Load Balancer Controller"
  type        = string
  default     = "AWSLoadBalancerControllerIAMPolicy"
}

variable "alb_controller_policy_json" {
  description = "IAM policy document for the AWS Load Balancer Controller"
  type        = string
}
