data "aws_route53_zone" "app" {
  name         = "${trimsuffix(var.hosted_zone_name, ".")}."
  private_zone = false
}

resource "aws_acm_certificate" "app" {
  domain_name       = var.certificate_domain_name != null ? var.certificate_domain_name : var.domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "app_certificate_validation" {
  for_each = {
    for option in aws_acm_certificate.app.domain_validation_options :
    option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.app.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for record in aws_route53_record.app_certificate_validation : record.fqdn]
}
