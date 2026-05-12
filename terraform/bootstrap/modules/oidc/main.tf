locals {
  common_tags = {
    Environment = var.environment
  }

  github_repository_full_names = [
    for repository in var.github_repositories : "${var.github_owner}/${repository}"
  ]
  allowed_subjects = concat(
    flatten([
      for repository in local.github_repository_full_names : [
        for branch in var.allowed_branches : "repo:${repository}:ref:refs/heads/${branch}"
      ]
    ]),
    var.allow_pull_requests ? [
      for repository in local.github_repository_full_names : "repo:${repository}:pull_request"
    ] : []
  )
}

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]

  tags = local.common_tags
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.allowed_subjects
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = var.github_oidc_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  lifecycle {
    precondition {
      condition     = length(local.allowed_subjects) > 0
      error_message = "Configure at least one allowed branch or enable pull request access for the GitHub OIDC role."
    }
  }

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  for_each = var.role_policy_arns

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}
