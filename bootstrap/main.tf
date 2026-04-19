###############################################################################
# Bootstrap — Create IAM roles in hub and consumer accounts for Terraform
###############################################################################

locals {
  terraform_role_name = "TerraformTGWLabRole"

  # Trust the SSO admin roles — each account has its own SSO role with a unique suffix.
  trusted_principals = [
    "arn:aws:iam::${var.hub_account_id}:role/aws-reserved/sso.amazonaws.com/${var.aws_region}/${var.hub_sso_role_name}",
    "arn:aws:iam::${var.consumer_account_id}:role/aws-reserved/sso.amazonaws.com/${var.aws_region}/${var.consumer_sso_role_name}",
  ]
}

# ---------- Hub account role ----------

data "aws_iam_policy_document" "hub_trust" {
  provider = aws.hub

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.trusted_principals
    }
  }
}

resource "aws_iam_role" "hub" {
  provider = aws.hub

  name               = local.terraform_role_name
  assume_role_policy = data.aws_iam_policy_document.hub_trust.json

  tags = {
    Purpose = "tgw-flow-log-lab"
  }
}

resource "aws_iam_role_policy_attachment" "hub" {
  provider = aws.hub

  role       = aws_iam_role.hub.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ---------- Consumer account role ----------

data "aws_iam_policy_document" "consumer_trust" {
  provider = aws.consumer

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.trusted_principals
    }
  }
}

resource "aws_iam_role" "consumer" {
  provider = aws.consumer

  name               = local.terraform_role_name
  assume_role_policy = data.aws_iam_policy_document.consumer_trust.json

  tags = {
    Purpose = "tgw-flow-log-lab"
  }
}

resource "aws_iam_role_policy_attachment" "consumer" {
  provider = aws.consumer

  role       = aws_iam_role.consumer.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
