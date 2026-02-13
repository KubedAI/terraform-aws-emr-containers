output "virtual_clusters" {
  description = "Map of team name to virtual cluster details"
  value = {
    for k, v in aws_emrcontainers_virtual_cluster.team : k => {
      id        = v.id
      arn       = v.arn
      name      = v.name
      namespace = local.team_namespaces[k]
    }
  }
}

output "job_execution_role_arns" {
  description = "Map of team name to job execution role ARN"
  value       = local.team_role_arns
}

output "cloudwatch_log_groups" {
  description = "Map of team name to CloudWatch log group details"
  value = {
    for k, v in aws_cloudwatch_log_group.team : k => {
      name = v.name
      arn  = v.arn
    }
  }
}

output "iam_role_names" {
  description = "Map of team name to job execution role name"
  value       = local.team_role_names
}

output "namespaces" {
  description = "Map of team name to Kubernetes namespace"
  value       = local.team_namespaces
}

output "pod_identity_service_accounts" {
  description = "Map of pod identity association key to service account name"
  value = {
    for k, v in local.pod_identity_associations : k => v.service_account
  }
}

output "cloudwatch_kms_key_arn" {
  description = "ARN of the module-managed CloudWatch KMS key (null when not created)"
  value       = try(aws_kms_key.cloudwatch[0].arn, null)
}
