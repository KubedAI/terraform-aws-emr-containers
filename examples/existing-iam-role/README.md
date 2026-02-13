# Existing IAM Role Example

This example demonstrates using a pre-existing IAM execution role with the EMR on EKS module. The IAM role is created outside the module and its ARN is passed in via `existing_iam_role_arn`.

## What This Creates

Outside the module:
- IAM execution role with a custom S3 policy

Inside the module:
- Kubernetes namespace
- EMR virtual cluster
- CloudWatch log group
- Pod Identity associations (using the externally provided role)

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
| `tags` | Tags to apply | `map(string)` | `{"Example": "existing-iam-role"}` |
