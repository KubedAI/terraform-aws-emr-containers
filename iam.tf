# iam.tf — IAM execution roles for EMR on EKS jobs
# Creates per-team IAM roles with scoped policies for S3, CloudWatch, and Glue.

################################################################################
# Locals
################################################################################

locals {
  # Teams that need a new IAM role created
  teams_create_role = {
    for k, v in var.teams : k => v if v.create_iam_role
  }

  # Resolved role ARN per team (created or existing)
  team_role_arns = {
    for k, v in var.teams : k => v.create_iam_role ? aws_iam_role.job_execution[k].arn : v.existing_iam_role_arn
  }

  # Resolved role name per team
  team_role_names = {
    for k, v in var.teams : k => v.create_iam_role ? aws_iam_role.job_execution[k].name : element(split("/", v.existing_iam_role_arn), length(split("/", v.existing_iam_role_arn)) - 1)
  }

  # Teams with additional IAM policy attachments — flatten to individual attachments
  team_policy_attachments = merge([
    for k, v in var.teams : {
      for idx, arn in v.additional_iam_policy_arns :
      "${k}-${idx}" => {
        team_key   = k
        policy_arn = arn
      }
    } if v.create_iam_role && length(v.additional_iam_policy_arns) > 0
  ]...)

  # Derived S3 object-level resource scope per team
  team_s3_object_resources = {
    for k, v in local.teams_create_role : k => (
      length(v.s3_object_prefixes) > 0 ?
      flatten([
        for arn in v.s3_bucket_arns : [
          for prefix in v.s3_object_prefixes :
          trim(prefix, "/") == "" ? "${arn}/*" : "${arn}/${trim(prefix, "/")}/*"
        ]
      ]) :
      [for arn in v.s3_bucket_arns : "${arn}/*"]
    )
  }

  # Optional s3:prefix condition values for ListBucket when prefixes are specified
  team_s3_list_prefixes = {
    for k, v in local.teams_create_role : k => [
      for prefix in v.s3_object_prefixes :
      trim(prefix, "/") == "" ? "*" : "${trim(prefix, "/")}/*"
    ]
  }
}

################################################################################
# Trust Policy
################################################################################

data "aws_iam_policy_document" "trust" {
  for_each = local.teams_create_role

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    dynamic "condition" {
      for_each = var.enable_pod_identity_trust_conditions ? [1] : []
      content {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }
}

################################################################################
# Execution Policy
################################################################################

data "aws_iam_policy_document" "job_execution" {
  for_each = local.teams_create_role

  # S3 bucket-level access (conditional)
  dynamic "statement" {
    for_each = length(each.value.s3_bucket_arns) > 0 ? [1] : []
    content {
      sid    = "S3BucketAccess"
      effect = "Allow"
      actions = [
        "s3:ListBucket",
        "s3:GetBucketLocation",
      ]
      resources = each.value.s3_bucket_arns

      dynamic "condition" {
        for_each = length(each.value.s3_object_prefixes) > 0 ? [1] : []
        content {
          test     = "StringLike"
          variable = "s3:prefix"
          values   = local.team_s3_list_prefixes[each.key]
        }
      }
    }
  }

  # S3 object-level access (conditional)
  dynamic "statement" {
    for_each = length(each.value.s3_bucket_arns) > 0 ? [1] : []
    content {
      sid    = "S3ObjectAccess"
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
      ]
      resources = local.team_s3_object_resources[each.key]
    }
  }

  # CloudWatch Logs — scoped to the team's log group
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:${local.team_log_group_names[each.key]}",
      "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:${local.team_log_group_names[each.key]}:*",
    ]
  }

  # DescribeLogGroups is an account-level API that does not support
  # resource-level scoping — it requires Resource: "*".
  # EMR validates this permission before starting job pods.
  statement {
    sid       = "CloudWatchDescribeLogGroups"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  # Glue catalog access (conditional)
  dynamic "statement" {
    for_each = each.value.attach_glue_policy ? [1] : []
    content {
      sid    = "GlueCatalog"
      effect = "Allow"
      actions = [
        "glue:GetDatabase",
        "glue:GetDatabases",
        "glue:GetTable",
        "glue:GetTables",
        "glue:GetPartition",
        "glue:GetPartitions",
        "glue:BatchGetPartition",
        "glue:GetUserDefinedFunction",
        "glue:GetUserDefinedFunctions",
      ]
      resources = ["*"]
    }
  }
}

################################################################################
# IAM Role and Policy Attachments
################################################################################

resource "aws_iam_role" "job_execution" {
  for_each = local.teams_create_role

  # Keep role names concise when possible; EMR service account names include
  # a base36 form of this role name. Some downstream policy/selectors apply
  # tighter length limits, so default to a short deterministic role name.
  # Override with iam_role_name when an explicit naming convention is required.
  name                 = coalesce(each.value.iam_role_name, "emr-${substr(md5("${var.eks_cluster_name}-${each.key}"), 0, 6)}")
  assume_role_policy   = data.aws_iam_policy_document.trust[each.key].json
  permissions_boundary = each.value.iam_role_permissions_boundary != null ? each.value.iam_role_permissions_boundary : var.iam_role_permissions_boundary

  tags = merge(var.tags, each.value.tags)
}

resource "aws_iam_role_policy" "job_execution" {
  for_each = local.teams_create_role

  name   = "emr-job-execution"
  role   = aws_iam_role.job_execution[each.key].id
  policy = data.aws_iam_policy_document.job_execution[each.key].json
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = local.team_policy_attachments

  role       = aws_iam_role.job_execution[each.value.team_key].name
  policy_arn = each.value.policy_arn
}
