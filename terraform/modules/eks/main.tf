# ─── Cluster IAM Role ────────────────────────────────────────────────────────

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name                  = "${var.cluster_name}-cluster-role"
  assume_role_policy    = data.aws_iam_policy_document.cluster_assume_role.json
  force_detach_policies = true

  tags = {
    Environment = "production"
  }
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ─── Node IAM Role ────────────────────────────────────────────────────────────

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name                  = "${var.cluster_name}-node-role"
  assume_role_policy    = data.aws_iam_policy_document.node_assume_role.json
  force_detach_policies = true

  tags = {
    Environment = "production"
  }
}

locals {
  node_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
  cluster_admin_principal_map = {
    for arn in var.cluster_admin_principal_arns : arn => arn
  }
}

resource "aws_iam_role_policy_attachment" "node_policies" {
  count = length(local.node_policies)

  role       = aws_iam_role.node.name
  policy_arn = local.node_policies[count.index]
}

# ─── Security Group ───────────────────────────────────────────────────────────

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-sg"
  description = "EKS cluster security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS API server"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-sg"
    Environment = "production"
  }
}

# ─── EKS Cluster ─────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "petclinic-eks-cluster" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.cluster.id]
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]

  tags = {
    Environment = "production"
  }
}

resource "aws_eks_access_entry" "cluster_admins" {
  for_each = local.cluster_admin_principal_map

  cluster_name  = aws_eks_cluster.petclinic-eks-cluster.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = {
    Environment = "production"
  }
}

resource "aws_eks_access_policy_association" "cluster_admins" {
  for_each = local.cluster_admin_principal_map

  cluster_name  = aws_eks_cluster.petclinic-eks-cluster.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.cluster_admins]
}

# ─── OIDC Provider (IRSA) ─────────────────────────────────────────────────────

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.petclinic-eks-cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  url             = aws_eks_cluster.petclinic-eks-cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]

  tags = {
    Environment = "production"
  }
}

# ─── Managed Node Group ───────────────────────────────────────────────────────

resource "aws_eks_node_group" "petclinic-node-group" {
  cluster_name    = aws_eks_cluster.petclinic-eks-cluster.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  depends_on = [aws_iam_role_policy_attachment.node_policies]

  tags = {
    Environment = "production"
  }
}

# ─── EBS CSI IRSA Role ────────────────────────────────────────────────────────

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc_provider.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json

  tags = {
    Environment = "production"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ─── Addons ───────────────────────────────────────────────────────────────────

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.petclinic-eks-cluster.name
  addon_name   = "coredns"

  depends_on = [aws_eks_node_group.petclinic-node-group]

  tags = {
    Environment = "production"
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.petclinic-eks-cluster.name
  addon_name   = "kube-proxy"

  depends_on = [aws_eks_node_group.petclinic-node-group]

  tags = {
    Environment = "production"
  }
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.petclinic-eks-cluster.name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = aws_iam_role.ebs_csi.arn
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [aws_eks_node_group.petclinic-node-group, aws_iam_role_policy_attachment.ebs_csi]

  timeouts {
    create = "30m"
  }

  tags = {
    Environment = "production"
  }
}
