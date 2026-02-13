# Basic Example

This example deploys a single EMR on EKS virtual cluster with all resources managed by the module:

- Kubernetes namespace
- EMR virtual cluster
- IAM execution role with S3 and Glue permissions
- CloudWatch log group
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
| `tags` | Tags to apply | `map(string)` | `{"Example": "basic"}` |
