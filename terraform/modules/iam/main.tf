locals {
  common_tags = {
    Environment = var.environment
  }

  oidc_provider_host = replace(var.oidc_provider_url, "https://", "")
  external_dns_zone_arns = [
    for zone_id in var.external_dns_zone_ids :
    "arn:aws:route53:::hostedzone/${zone_id}"
  ]
}

data "aws_iam_policy_document" "eso_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = ["system:serviceaccount:${var.eso_namespace}:${var.eso_service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = var.eso_role_name
  assume_role_policy = data.aws_iam_policy_document.eso_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eso_secrets_manager" {
  role       = aws_iam_role.eso.name
  policy_arn = var.eso_policy_arn
}

resource "aws_iam_policy" "alb_controller" {
  name   = var.alb_policy_name
  policy = var.alb_controller_policy_json

  tags = local.common_tags
}

data "aws_iam_policy_document" "alb_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = ["system:serviceaccount:${var.alb_namespace}:${var.alb_service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = var.alb_role_name
  assume_role_policy = data.aws_iam_policy_document.alb_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

data "aws_iam_policy_document" "external_dns_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:sub"
      values   = ["system:serviceaccount:${var.external_dns_namespace}:${var.external_dns_service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name               = var.external_dns_role_name
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "external_dns_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
    ]
    resources = local.external_dns_zone_arns
  }

  statement {
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "route53:GetChange",
    ]
    resources = ["arn:aws:route53:::change/*"]
  }
}

resource "aws_iam_role_policy" "external_dns" {
  name   = "${var.external_dns_role_name}-policy"
  role   = aws_iam_role.external_dns.id
  policy = data.aws_iam_policy_document.external_dns_permissions.json
}
