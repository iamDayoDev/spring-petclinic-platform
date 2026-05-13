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
