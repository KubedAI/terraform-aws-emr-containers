# Existing CloudWatch Log Group Example

This example demonstrates using a pre-existing CloudWatch log group with the EMR on EKS module. The log group is created outside the module and its name is passed in via `cloudwatch_log_group_name`.

## What This Creates

Outside the module:
- CloudWatch log group with 90-day retention

Inside the module:
- Kubernetes namespace
- EMR virtual cluster
- IAM execution role (with CloudWatch policy scoped to the existing log group)
- Pod Identity associations

## Usage

```bash
terraform init
terraform plan -var="eks_cluster_name=my-cluster"
terraform apply -var="eks_cluster_name=my-cluster"
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `region` | AWS region | `string` | `"us-west-2"` |
| `eks_cluster_name` | Name of the existing EKS cluster | `string` | n/a |
| `tags` | Tags to apply | `map(string)` | `{"Example": "existing-cloudwatch-log-group"}` |
