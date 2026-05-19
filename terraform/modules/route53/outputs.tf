output "hosted_zone_id" {
  description = "Public Route 53 hosted zone ID"
  value       = data.aws_route53_zone.app.zone_id
}

output "certificate_arn" {
  description = "Validated ACM certificate ARN for the exposed hostnames"
  value       = aws_acm_certificate_validation.app.certificate_arn
}

output "certificate_validation_record_fqdns" {
  description = "DNS records used to validate the ACM certificate"
  value       = [for record in aws_route53_record.app_certificate_validation : record.fqdn]
}
