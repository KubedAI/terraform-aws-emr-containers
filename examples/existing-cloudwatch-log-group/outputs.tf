output "virtual_clusters" {
  description = "Virtual cluster details"
  value       = module.emr_on_eks.virtual_clusters
}

output "job_execution_role_arns" {
  description = "Job execution role ARNs"
  value       = module.emr_on_eks.job_execution_role_arns
}

output "existing_log_group_arn" {
  description = "The externally managed CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.emr.arn
}
