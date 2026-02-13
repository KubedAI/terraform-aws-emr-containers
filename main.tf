# main.tf — EMR on EKS virtual clusters
# Creates per-team Kubernetes namespaces and EMR virtual clusters.

################################################################################
# Locals
################################################################################

locals {
  team_namespaces = {
    for k, v in var.teams : k => coalesce(v.namespace, "emr-${k}")
  }

  # Teams that need namespace creation
  teams_create_namespace = {
    for k, v in var.teams : k => v if v.create_namespace
  }

  # Resolved CloudWatch log group name per team
  team_log_group_names = {
    for k, v in var.teams : k => coalesce(
      v.cloudwatch_log_group_name,
      "/emr-on-eks/${var.eks_cluster_name}/${k}"
    )
  }
}

################################################################################
# Kubernetes Namespaces
################################################################################

resource "kubernetes_namespace_v1" "team" {
  for_each = local.teams_create_namespace

  metadata {
    name = local.team_namespaces[each.key]
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "emr-on-eks"                   = "enabled"
    }
  }
}

################################################################################
# EMR Virtual Clusters
################################################################################

resource "aws_emrcontainers_virtual_cluster" "team" {
  for_each = var.teams

  name = "${var.eks_cluster_name}-${each.key}"

  container_provider {
    id   = var.eks_cluster_name
    type = "EKS"

    info {
      eks_info {
        namespace = local.team_namespaces[each.key]
      }
    }
  }

  tags = merge(var.tags, each.value.tags)

  depends_on = [
    kubernetes_namespace_v1.team,
    kubernetes_role_binding_v1.emr_containers,
  ]
}
