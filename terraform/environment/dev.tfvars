aws_region  = "us-east-1"
cluster_name = "petclinic-eks"
environment  = "dev"
repository_prefix = "petclinic-dev"
app_namespace = "petclinic"
node_instance_type = "t3.small"
node_desired_size = 2
node_min_size = 1
node_max_size = 3

domain = "etaoko.com"
eso_role_name  = "petclinic-eso-role"
alb_role_name  = "petclinic-alb-role"
alb_policy_name = "AWSLoadBalancerControllerIAMPolicy"

cluster_admin_principal_arns = [
  "arn:aws:iam::979779072306:user/Aderinto",
  "arn:aws:iam::979779072306:role/oidc-github-role",
]
