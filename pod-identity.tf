# pod-identity.tf — EKS Pod Identity associations for EMR on EKS
#
# EMR on EKS requires three service accounts (client, driver, executor)
# whose names embed the base36-encoded IAM role name. The encode provider
# computes this value so Terraform can manage pod identity associations
# without delegating to external scripts or the AWS CLI.

locals {
  pod_identity_components = ["client", "driver", "executor"]

  pod_identity_associations = merge([
    for team_key in keys(var.teams) : {
      for component in local.pod_identity_components :
      "${team_key}-${component}" => {
        team_key        = team_key
        namespace       = local.team_namespaces[team_key]
        service_account = "emr-containers-sa-spark-${component}-${data.aws_caller_identity.current.account_id}-${data.encode_base36.team_role_name[team_key].result}"
      }
    }
  ]...)
}

################################################################################
# Base36 Encoding and Pod Identity Associations
################################################################################

data "encode_base36" "team_role_name" {
  for_each = local.team_role_names

  value     = each.value
  lowercase = true
}

resource "aws_eks_pod_identity_association" "team" {
  for_each = local.pod_identity_associations

  cluster_name    = var.eks_cluster_name
  namespace       = each.value.namespace
  service_account = each.value.service_account
  role_arn        = local.team_role_arns[each.value.team_key]

  depends_on = [
    aws_iam_role.job_execution,
    kubernetes_namespace_v1.team,
  ]
}
