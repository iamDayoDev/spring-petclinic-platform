locals {
  eso_namespace             = "external-secrets"
  eso_service_account_name  = "external-secrets"
  alb_namespace             = "kube-system"
  alb_service_account_name  = "aws-load-balancer-controller"
  cluster_secret_store_name = "aws-secrets-manager"
}

module "vpc" {
  source = "./modules/vpc"
}

module "eks" {
  source = "./modules/eks"

  cluster_name                 = var.cluster_name
  cluster_admin_principal_arns = var.cluster_admin_principal_arns
  node_instance_type           = var.node_instance_type
  node_desired_size            = var.node_desired_size
  node_min_size                = var.node_min_size
  node_max_size                = var.node_max_size
  vpc_id                       = module.vpc.vpc_id
  subnet_ids                   = module.vpc.public_subnet_ids
}

module "iam" {
  source = "./modules/iam"

  environment                = var.environment
  oidc_provider_arn          = module.eks.oidc_provider_arn
  oidc_provider_url          = module.eks.oidc_provider_url
  eso_role_name              = var.eso_role_name
  eso_namespace              = local.eso_namespace
  eso_service_account_name   = local.eso_service_account_name
  alb_role_name              = var.alb_role_name
  alb_namespace              = local.alb_namespace
  alb_service_account_name   = local.alb_service_account_name
  alb_policy_name            = var.alb_policy_name
  alb_controller_policy_json = file("${path.module}/iam_policy.json")
}

module "addons" {
  source = "./modules/addons"

  aws_region                = var.aws_region
  vpc_id                    = module.vpc.vpc_id
  app_namespace             = var.app_namespace
  cluster_secret_store_name = local.cluster_secret_store_name
  eso_namespace             = local.eso_namespace
  eso_service_account_name  = local.eso_service_account_name
  eso_role_arn              = module.iam.eso_role_arn
  alb_namespace             = local.alb_namespace
  alb_service_account_name  = local.alb_service_account_name
  alb_role_arn              = module.iam.alb_role_arn
  cluster_name              = module.eks.cluster_name

  depends_on = [module.eks, module.iam, time_sleep.wait_for_eks_api_access]
}

module "ecr" {
  source = "./modules/ecr"

  environment       = var.environment
  repository_prefix = var.repository_prefix
}

# RDS security group uses the VPC CIDR to allow EKS nodes.
# No explicit node security group ID is exported by the EKS module.
module "rds" {
  source = "./modules/rds"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
  eks_cidr   = module.vpc.vpc_cidr
}
