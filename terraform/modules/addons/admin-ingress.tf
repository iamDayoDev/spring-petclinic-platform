locals {
  admin_ingress_group_name = "petclinic-admin"

  admin_ingress_annotations = {
    "kubernetes.io/ingress.class"               = "alb"
    "alb.ingress.kubernetes.io/group.name"      = local.admin_ingress_group_name
    "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
    "alb.ingress.kubernetes.io/target-type"     = "ip"
    "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\":80},{\"HTTPS\":443}]"
    "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
    "alb.ingress.kubernetes.io/certificate-arn" = var.certificate_arn
    "alb.ingress.kubernetes.io/success-codes"   = "200-399"
  }

  admin_ingresses = {
    argocd = {
      namespace        = var.argocd_namespace
      host             = var.argocd_hostname
      service_name     = "${helm_release.argocd.name}-server"
      service_port     = 80
      healthcheck_path = "/healthz"
    }
    grafana = {
      namespace        = var.monitoring_namespace
      host             = var.grafana_hostname
      service_name     = "${helm_release.monitoring.name}-grafana"
      service_port     = 80
      healthcheck_path = "/api/health"
    }
    prometheus = {
      namespace        = var.monitoring_namespace
      host             = var.prometheus_hostname
      service_name     = "${helm_release.monitoring.name}-kube-prometheus-prometheus"
      service_port     = 9090
      healthcheck_path = "/-/ready"
    }
    zipkin = {
      namespace        = var.monitoring_namespace
      host             = var.zipkin_hostname
      service_name     = kubernetes_service_v1.zipkin.metadata[0].name
      service_port     = 9411
      healthcheck_path = "/health"
    }
  }
}

resource "kubernetes_ingress_v1" "admin_tools" {
  for_each = local.admin_ingresses

  metadata {
    name      = "${each.key}-ingress"
    namespace = each.value.namespace
    annotations = merge(
      local.admin_ingress_annotations,
      {
        "external-dns.alpha.kubernetes.io/hostname" = each.value.host
        "alb.ingress.kubernetes.io/healthcheck-path" = each.value.healthcheck_path
      }
    )
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = each.value.host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = each.value.service_name

              port {
                number = each.value.service_port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    helm_release.monitoring,
    kubernetes_service_v1.zipkin,
    helm_release.external_dns,
  ]
}
