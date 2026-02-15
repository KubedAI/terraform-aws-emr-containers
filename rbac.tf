# rbac.tf — Namespace-scoped Kubernetes RBAC for EMR on EKS
# Creates Role and RoleBinding per team namespace to allow EMR to orchestrate jobs.
#
# NOTE: This is only needed for clusters using the legacy aws-auth ConfigMap
# authentication. Clusters using EKS Access Entries (recommended for EKS 1.23+)
# get RBAC created automatically by the CreateVirtualCluster API.

locals {
  # Teams that need namespace-scoped EMR on EKS RBAC created
  teams_create_emr_rbac = {
    for k, v in var.teams : k => v if v.create_emr_rbac
  }
}

resource "kubernetes_role_v1" "emr_containers" {
  for_each = local.teams_create_emr_rbac

  metadata {
    name      = "emr-containers"
    namespace = local.team_namespaces[each.key]
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "emr-on-eks"                   = "enabled"
    }
  }

  # Core resources for EMR on EKS job orchestration
  rule {
    api_groups = [""]
    resources = [
      "configmaps",
      "events",
      "namespaces",
      "persistentvolumeclaims",
      "pods",
      "pods/log",
      "serviceaccounts",
      "services",
    ]
    verbs = [
      "create",
      "delete",
      "deletecollection",
      "get",
      "list",
      "patch",
      "update",
      "watch",
    ]
  }

  # Secrets — restricted verbs (no get/list per AWS docs)
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs = [
      "create",
      "delete",
      "deletecollection",
      "patch",
      "watch",
    ]
  }

  # RBAC resources
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources = [
      "rolebindings",
      "roles",
    ]
    verbs = [
      "create",
      "delete",
      "deletecollection",
      "get",
      "list",
      "patch",
      "update",
      "watch",
    ]
  }

  # Apps resources
  rule {
    api_groups = ["apps"]
    resources = [
      "deployments",
      "statefulsets",
    ]
    verbs = [
      "create",
      "delete",
      "deletecollection",
      "get",
      "list",
      "patch",
      "update",
      "watch",
    ]
  }

  # Batch resources
  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs = [
      "create",
      "delete",
      "deletecollection",
      "get",
      "list",
      "patch",
      "update",
      "watch",
    ]
  }

  # Networking resources
  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs = [
      "create",
      "delete",
      "deletecollection",
      "get",
      "list",
      "patch",
      "update",
      "watch",
    ]
  }

  depends_on = [kubernetes_namespace_v1.team]
}

resource "kubernetes_role_binding_v1" "emr_containers" {
  for_each = local.teams_create_emr_rbac

  metadata {
    name      = "emr-containers"
    namespace = local.team_namespaces[each.key]
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "emr-on-eks"                   = "enabled"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.emr_containers[each.key].metadata[0].name
  }

  subject {
    kind      = "User"
    name      = "emr-containers"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [kubernetes_namespace_v1.team]
}
