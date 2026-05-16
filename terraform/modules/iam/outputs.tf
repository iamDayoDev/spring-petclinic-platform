output "eso_role_name" {
  description = "IAM role name for External Secrets Operator"
  value       = aws_iam_role.eso.name
}

output "eso_role_arn" {
  description = "IAM role ARN for External Secrets Operator"
  value       = aws_iam_role.eso.arn
}

output "alb_role_name" {
  description = "IAM role name for the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.name
}

output "alb_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.arn
}

output "alb_policy_arn" {
  description = "Customer-managed IAM policy ARN for the AWS Load Balancer Controller"
  value       = aws_iam_policy.alb_controller.arn
}

output "external_dns_role_name" {
  description = "IAM role name for ExternalDNS"
  value       = aws_iam_role.external_dns.name
}

output "external_dns_role_arn" {
  description = "IAM role ARN for ExternalDNS"
  value       = aws_iam_role.external_dns.arn
}
