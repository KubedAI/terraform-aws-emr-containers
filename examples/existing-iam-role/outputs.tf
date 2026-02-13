output "virtual_clusters" {
  description = "Virtual cluster details"
  value       = module.emr_on_eks.virtual_clusters
}

output "job_execution_role_arns" {
  description = "Job execution role ARNs"
  value       = module.emr_on_eks.job_execution_role_arns
}

output "existing_role_arn" {
  description = "The externally managed IAM role ARN passed to the module"
  value       = aws_iam_role.emr_execution.arn
}
