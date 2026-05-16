resource "helm_release" "monitoring" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = var.monitoring_namespace
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [
    file("${path.module}/values/kube-prometheus-stack.yaml"),
    yamlencode({
      grafana = {
        service = {
          type = var.monitoring_grafana_service_type
        }
        additionalDataSources = [
          {
            name   = "Zipkin"
            type   = "zipkin"
            access = "proxy"
            url    = "http://zipkin.${var.monitoring_namespace}.svc.cluster.local:9411"
          }
        ]
      }
      prometheus = {
        prometheusSpec = {
          podMonitorNamespaceSelector = {
            matchNames = [
              var.app_namespace,
              var.monitoring_namespace,
            ]
          }
          podMonitorSelector = {
            matchLabels = {
              release = "monitoring"
            }
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.app]
}

resource "kubernetes_deployment_v1" "zipkin" {
  metadata {
    name      = "zipkin"
    namespace = var.monitoring_namespace
    labels = {
      app = "zipkin"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "zipkin"
      }
    }

    template {
      metadata {
        labels = {
          app = "zipkin"
        }
      }

      spec {
        container {
          name  = "zipkin"
          image = "openzipkin/zipkin:latest"

          port {
            container_port = 9411
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 9411
            }
            initial_delay_seconds = 20
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 9411
            }
            initial_delay_seconds = 60
            period_seconds        = 20
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.monitoring]
}

resource "kubernetes_service_v1" "zipkin" {
  metadata {
    name      = "zipkin"
    namespace = var.monitoring_namespace
    labels = {
      app = "zipkin"
    }
  }

  spec {
    selector = {
      app = "zipkin"
    }

    type = var.monitoring_zipkin_service_type

    port {
      port        = 9411
      target_port = 9411
      protocol    = "TCP"
    }
  }

  depends_on = [
    kubernetes_deployment_v1.zipkin,
    helm_release.aws_load_balancer_controller,
  ]
}
