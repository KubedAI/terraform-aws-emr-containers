output "virtual_clusters" {
  description = "Map of team name to virtual cluster details"
  value       = module.emr_on_eks.virtual_clusters
}

output "job_execution_role_arns" {
  description = "Map of team name to job execution role ARN"
  value       = module.emr_on_eks.job_execution_role_arns
}

output "cloudwatch_log_groups" {
  description = "Map of team name to CloudWatch log group details"
  value       = module.emr_on_eks.cloudwatch_log_groups
}
