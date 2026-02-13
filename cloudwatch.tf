# cloudwatch.tf — CloudWatch log groups and optional KMS encryption
#
# KMS key strategy (three levels, highest priority first):
#   1. Team-level key   — teams[k].cloudwatch_kms_key_id
#   2. Module-level key — var.cloudwatch_kms_key_id (bring your own)
#   3. Module-managed   — created here when var.create_cloudwatch_kms_key = true
#
# Set enable_cloudwatch_kms_encryption = false to disable encryption entirely.

################################################################################
# Locals
################################################################################

locals {
  # Teams that need a CloudWatch log group created
  teams_create_log_group = {
    for k, v in var.teams : k => v if v.create_cloudwatch_log_group
  }

  # Create a module-managed KMS key when encryption is enabled and no external key is provided.
  create_module_cloudwatch_kms_key = var.enable_cloudwatch_kms_encryption && var.cloudwatch_kms_key_id == null && var.create_cloudwatch_kms_key

  module_cloudwatch_kms_key_arn = local.create_module_cloudwatch_kms_key ? aws_kms_key.cloudwatch[0].arn : null

  # Resolved KMS key ARN per team log group.
  team_log_group_kms_key_arns = {
    for k, v in var.teams : k => (
      var.enable_cloudwatch_kms_encryption
      ? (
        v.cloudwatch_kms_key_id != null ? v.cloudwatch_kms_key_id : (
          var.cloudwatch_kms_key_id != null ? var.cloudwatch_kms_key_id : local.module_cloudwatch_kms_key_arn
        )
      )
      : null
    )
  }
}

data "aws_iam_policy_document" "cloudwatch_logs_kms" {
  count = local.create_module_cloudwatch_kms_key ? 1 : 0

  statement {
    sid    = "AllowAccountAdministration"
    effect = "Allow"
    actions = [
      "kms:*",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowCloudWatchLogsUsage"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.id}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_kms_key" "cloudwatch" {
  count = local.create_module_cloudwatch_kms_key ? 1 : 0

  description             = var.cloudwatch_kms_key_description
  deletion_window_in_days = var.cloudwatch_kms_key_deletion_window_in_days
  enable_key_rotation     = var.cloudwatch_kms_key_enable_rotation
  policy                  = data.aws_iam_policy_document.cloudwatch_logs_kms[0].json

  tags = merge(var.tags, { Name = "${var.eks_cluster_name}-emr-cloudwatch-logs" })
}

resource "aws_cloudwatch_log_group" "team" {
  for_each = local.teams_create_log_group

  name              = local.team_log_group_names[each.key]
  retention_in_days = each.value.cloudwatch_log_group_retention
  kms_key_id        = local.team_log_group_kms_key_arns[each.key]

  lifecycle {
    precondition {
      condition     = !var.enable_cloudwatch_kms_encryption || local.team_log_group_kms_key_arns[each.key] != null
      error_message = "CloudWatch KMS encryption is enabled, but no KMS key could be resolved. Set cloudwatch_kms_key_id or enable create_cloudwatch_kms_key."
    }
  }

  tags = merge(var.tags, each.value.tags)

  depends_on = [aws_kms_key.cloudwatch]
}
