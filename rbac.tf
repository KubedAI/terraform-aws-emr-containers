# rbac.tf — Namespace-scoped Kubernetes RBAC for EMR on EKS
# Creates Role and RoleBinding per team namespace to allow EMR to orchestrate jobs.

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

  # Namespace-scoped permissions for EMR on EKS to orchestrate jobs.
  rule {
    api_groups = [""]
    resources = [
      "configmaps",
      "events",
      "persistentvolumeclaims",
      "pods",
      "pods/log",
      "secrets",
      "serviceaccounts",
      "services",
    ]
    verbs = [
      "create",
      "delete",
      "get",
      "list",
      "patch",
      "update",
      "watch",
    ]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources = [
      "rolebindings",
      "roles",
    ]
    verbs = [
      "create",
      "delete",
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
