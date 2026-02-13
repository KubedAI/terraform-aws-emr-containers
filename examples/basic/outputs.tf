output "virtual_clusters" {
  description = "Virtual cluster details"
  value       = module.emr_on_eks.virtual_clusters
}

output "job_execution_role_arns" {
  description = "Job execution role ARNs"
  value       = module.emr_on_eks.job_execution_role_arns
}

output "cloudwatch_log_groups" {
  description = "CloudWatch log group details"
  value       = module.emr_on_eks.cloudwatch_log_groups
}
