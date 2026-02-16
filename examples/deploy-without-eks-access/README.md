# deploy-without-eks-access

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.28 |
| <a name="requirement_encode"></a> [encode](#requirement\_encode) | 0.3.0-beta.1 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_emr_on_eks"></a> [emr\_on\_eks](#module\_emr\_on\_eks) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_region"></a> [region](#input\_region) | AWS region | `string` | `"us-west-2"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | <pre>{<br/>  "Example": "deploy-without-eks-access"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudwatch_log_groups"></a> [cloudwatch\_log\_groups](#output\_cloudwatch\_log\_groups) | Map of team name to CloudWatch log group details |
| <a name="output_job_execution_role_arns"></a> [job\_execution\_role\_arns](#output\_job\_execution\_role\_arns) | Map of team name to job execution role ARN |
| <a name="output_virtual_clusters"></a> [virtual\_clusters](#output\_virtual\_clusters) | Map of team name to virtual cluster details |
<!-- END_TF_DOCS -->
