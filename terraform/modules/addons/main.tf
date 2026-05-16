resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.app_namespace
  }
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = var.eso_namespace
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      installCRDs = true
      serviceAccount = {
        create = true
        name   = var.eso_service_account_name
        annotations = {
          "eks.amazonaws.com/role-arn" = var.eso_role_arn
        }
      }
    })
  ]
}

resource "helm_release" "external_secrets_bootstrap" {
  name      = "external-secrets-bootstrap"
  chart     = "${path.module}/charts/external-secrets-bootstrap"
  namespace = var.eso_namespace
  wait      = true
  timeout   = 300

  values = [
    yamlencode({
      clusterSecretStore = {
        name                    = var.cluster_secret_store_name
        region                  = var.aws_region
        serviceAccountName      = var.eso_service_account_name
        serviceAccountNamespace = var.eso_namespace
      }
    })
  ]

  depends_on = [helm_release.external_secrets]
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = var.alb_namespace
  wait       = true
  timeout    = 600

  values = [
    yamlencode({
      clusterName = var.cluster_name
      region      = var.aws_region
      vpcId       = var.vpc_id
      enableServiceMutatorWebhook = false
      serviceAccount = {
        create = true
        name   = var.alb_service_account_name
        annotations = {
          "eks.amazonaws.com/role-arn" = var.alb_role_arn
        }
      }
    })
  ]

  depends_on = [helm_release.external_secrets_bootstrap]
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = var.external_dns_namespace
  wait       = true
  timeout    = 600

  values = [
    yamlencode({
      provider = {
        name = "aws"
      }
      policy       = "upsert-only"
      txtOwnerId   = var.cluster_name
      domainFilters = [trimsuffix(var.hosted_zone_name, ".")]
      sources      = ["ingress"]
      extraArgs = {
        "aws-zone-type" = "public"
      }
      serviceAccount = {
        create = true
        name   = var.external_dns_service_account_name
        annotations = {
          "eks.amazonaws.com/role-arn" = var.external_dns_role_arn
        }
      }
    })
  ]

  depends_on = [helm_release.aws_load_balancer_controller]
}
