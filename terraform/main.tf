# ─── VPC ─────────────────────────────────────────────────────────────────────

module "vpc" {
  source = "./modules/vpc"
}

# ─── EKS ─────────────────────────────────────────────────────────────────────

module "eks" {
  source = "./modules/eks"

  cluster_name = var.cluster_name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.public_subnet_ids
}

# ─── ECR ─────────────────────────────────────────────────────────────────────

module "ecr" {
  source = "./modules/ecr"
}

# ─── RDS ─────────────────────────────────────────────────────────────────────
# RDS security group uses CIDR 10.0.0.0/16 (the VPC CIDR) to allow EKS nodes.
# No explicit node security group ID is exported by the EKS module.

module "rds" {
  source = "./modules/rds"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
  eks_cidr   = module.vpc.vpc_cidr
}
