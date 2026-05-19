resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = var.argocd_namespace
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [
    file("${path.module}/values/argocd.yaml"),
    yamlencode({
      configs = {
        cm = {
          url = "https://${var.argocd_hostname}"
        }
      }
      server = {
        service = {
          type = var.argocd_server_service_type
        }
      }
    })
  ]
}
