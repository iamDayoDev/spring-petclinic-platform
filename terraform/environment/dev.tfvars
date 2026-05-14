aws_region  = "us-east-1"
cluster_name = "petclinic-eks"
environment  = "dev"
repository_prefix = "petclinic-dev"
app_namespace = "petclinic"
monitoring_grafana_service_type = "LoadBalancer"
argocd_server_service_type = "LoadBalancer"
node_instance_type = "t3.medium"
node_desired_size = 3
node_min_size = 2
node_max_size = 5

domain = "petclinic.dayoclouddev.site"
eso_role_name  = "petclinic-eso-role"
alb_role_name  = "petclinic-alb-role"
alb_policy_name = "AWSLoadBalancerControllerIAMPolicy"

cluster_admin_principal_arns = [
  "arn:aws:iam::536697234487:user/Joshua",
  "arn:aws:iam::536697234487:role/oidc-github-role",
]
