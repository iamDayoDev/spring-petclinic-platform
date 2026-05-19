variable "domain" {
  description = "Fully qualified application hostname to secure with ACM"
  type        = string
}

variable "certificate_domain_name" {
  description = "Primary ACM certificate domain name. Set a wildcard to cover multiple subdomains."
  type        = string
  default     = null
}

variable "hosted_zone_name" {
  description = "Public Route 53 hosted zone that owns the application hostname"
  type        = string
}
