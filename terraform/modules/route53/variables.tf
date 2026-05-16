variable "domain" {
  description = "Fully qualified application hostname to secure with ACM"
  type        = string
}

variable "hosted_zone_name" {
  description = "Public Route 53 hosted zone that owns the application hostname"
  type        = string
}
