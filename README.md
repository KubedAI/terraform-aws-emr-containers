# terraform-aws-emr-containers

Terraform module for provisioning EMR on EKS virtual clusters with multi-tenancy support. Each team gets its own Kubernetes namespace, EMR virtual cluster, IAM execution role, CloudWatch log group, and Pod Identity associations.

## Features

- Multi-tenancy via a `teams` map -- define as many teams as needed
- Pod Identity associations (not IRSA) with automatic base36 service account naming
- Conditional namespace creation (`create_namespace = false` for pre-existing namespaces)
- Namespace-scoped Kubernetes RBAC for EMR on EKS (`create_emr_rbac = true` by default)
- Conditional IAM role creation (`create_iam_role = false` to bring your own role)
- Conditional CloudWatch log group creation (`create_cloudwatch_log_group = false` to bring your own)
- Scoped IAM policies: S3 (bucket/object split with optional prefix scoping), CloudWatch Logs, Glue catalog
- CloudWatch Logs encryption with customer-managed KMS keys (module-managed key by default)
- Optional IAM permissions boundary on created execution roles
- Optional pod identity trust-policy hardening with source-account condition
- Deterministic short IAM role names to reduce generated service account length

## Usage

```hcl
module "emr_on_eks" {
  source = "github.com/KubedAI/terraform-aws-emr-containers"

  eks_cluster_name = "my-eks-cluster"

  teams = {
    analytics = {
      s3_bucket_arns     = ["arn:aws:s3:::my-data-bucket"]
      attach_glue_policy = true
    }

    data-science = {
      namespace      = "ds-emr"
      s3_bucket_arns = ["arn:aws:s3:::ds-bucket"]
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| [terraform](https://www.terraform.io/) | >= 1.5.7 |
| [aws](https://registry.terraform.io/providers/hashicorp/aws) | >= 6.28 |
| [kubernetes](https://registry.terraform.io/providers/hashicorp/kubernetes) | >= 2.38 |
| [encode](https://registry.terraform.io/providers/justenwalker/encode) | 0.3.0-beta.1 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.28 |
| kubernetes | >= 2.38 |
| encode | 0.3.0-beta.1 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `eks_cluster_name` | Name of the existing EKS cluster | `string` | n/a | yes |
| `tags` | Tags to apply to all resources | `map(string)` | `{}` | no |
| `enable_pod_identity_trust_conditions` | Add source-account trust condition to pod identity roles | `bool` | `true` | no |
| `iam_role_permissions_boundary` | Default permissions boundary ARN for created IAM roles | `string` | `null` | no |
| `enable_cloudwatch_kms_encryption` | Encrypt module-managed CloudWatch log groups with CMK | `bool` | `true` | no |
| `cloudwatch_kms_key_id` | Existing KMS key ARN for CloudWatch log groups | `string` | `null` | no |
| `create_cloudwatch_kms_key` | Create a KMS key when encryption is enabled and no external key is provided | `bool` | `true` | no |
| `cloudwatch_kms_key_enable_rotation` | Enable key rotation for module-managed KMS key | `bool` | `true` | no |
| `cloudwatch_kms_key_deletion_window_in_days` | KMS key deletion window in days | `number` | `30` | no |
| `cloudwatch_kms_key_description` | Description for module-managed KMS key | `string` | `"KMS key for EMR on EKS CloudWatch Logs encryption"` | no |
| `teams` | Map of team configurations for EMR virtual clusters | `map(object({...}))` | n/a | yes |

### Team Object Fields

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `namespace` | Kubernetes namespace name | `string` | `"emr-{team_key}"` |
| `create_namespace` | Whether to create the Kubernetes namespace | `bool` | `true` |
| `create_emr_rbac` | Whether to create namespace-scoped Kubernetes Role and RoleBinding for EMR on EKS | `bool` | `true` |
| `create_iam_role` | Whether to create an IAM execution role | `bool` | `true` |
| `iam_role_name` | Custom IAM role name (overrides auto-generated) | `string` | `null` |
| `iam_role_permissions_boundary` | Team-specific IAM permissions boundary ARN (overrides module default) | `string` | `null` |
| `existing_iam_role_arn` | ARN of existing IAM role (required when `create_iam_role = false`) | `string` | `null` |
| `s3_bucket_arns` | S3 bucket ARNs for the execution role policy | `list(string)` | `[]` |
| `s3_object_prefixes` | Optional S3 key prefixes to scope object access and ListBucket prefix conditions | `list(string)` | `[]` |
| `attach_glue_policy` | Whether to attach Glue catalog read permissions | `bool` | `false` |
| `additional_iam_policy_arns` | Additional IAM policy ARNs to attach to the execution role | `list(string)` | `[]` |
| `create_cloudwatch_log_group` | Whether to create a CloudWatch log group | `bool` | `true` |
| `cloudwatch_log_group_name` | Custom CloudWatch log group name | `string` | `"/emr-on-eks/{cluster}/{team}"` |
| `cloudwatch_log_group_retention` | Log group retention in days | `number` | `30` |
| `cloudwatch_kms_key_id` | Team-specific KMS key ARN for CloudWatch log group encryption | `string` | `null` |
| `tags` | Team-specific tags (merged with module-level tags) | `map(string)` | `{}` |

Validation notes:
- `create_namespace = false` requires `namespace` to be set.
- `create_iam_role = false` requires `existing_iam_role_arn` to be set.
- `create_cloudwatch_log_group = false` requires `cloudwatch_log_group_name` to be set.

## Outputs

| Name | Description |
|------|-------------|
| `virtual_clusters` | Map of team name to virtual cluster details (id, arn, name, namespace) |
| `job_execution_role_arns` | Map of team name to job execution role ARN |
| `iam_role_names` | Map of team name to job execution role name |
| `namespaces` | Map of team name to Kubernetes namespace |
| `pod_identity_service_accounts` | Map of pod identity association key to service account name |
| `cloudwatch_log_groups` | Map of team name to CloudWatch log group details (name, arn) |
| `cloudwatch_kms_key_arn` | ARN of module-managed CloudWatch KMS key (when created) |

## Examples

| Example | Description |
|---------|-------------|
| [basic](./examples/basic/) | Single team with all resources managed by the module |
| [existing-iam-role](./examples/existing-iam-role/) | Bring your own IAM execution role |
| [existing-cloudwatch-log-group](./examples/existing-cloudwatch-log-group/) | Bring your own CloudWatch log group |

## How It Works

### Pod Identity and Base36 Encoding

EMR on EKS creates Kubernetes service accounts with the naming pattern:

```
emr-containers-sa-spark-{ROLE}-{ACCOUNT_ID}-{BASE36_ENCODED_ROLE_NAME}
```

Where `ROLE` is one of `client`, `driver`, or `executor`. The module uses the `justenwalker/encode` provider to compute the base36 encoding, matching the algorithm used by the AWS CLI (`awscli/customizations/emrcontainers/base36.py`).

### Kubernetes RBAC

By default, the module creates a namespace-scoped `Role` and `RoleBinding` named `emr-containers` per team namespace. This follows the EMR on EKS manual cluster-access model and grants the `emr-containers` Kubernetes user the permissions needed to orchestrate workloads inside that namespace.

Note: this module does not manage EKS authentication mappings (`aws-auth` ConfigMap or EKS access entries). If your cluster requires manual access mapping for the `emr-containers` user, configure that separately.

### IAM Role Naming

Default IAM role names use an MD5-based short hash (`emr-{hash6}`) to keep generated service account names compact for downstream policy/selectors that may enforce tighter limits. Override with `iam_role_name` if you need a specific naming convention.

### Security Defaults

- CloudWatch log groups are encrypted with a customer-managed KMS key by default.
- Pod identity trust policies include an `aws:SourceAccount` condition by default.
- S3 access can be narrowed to key prefixes using `s3_object_prefixes`.
- IAM role permissions boundaries can be enforced globally or per team.

## Disclaimer

This is an independent open-source project maintained by [KubedAI](https://github.com/KubedAI) and is **not** affiliated with, sponsored by, or officially supported by Amazon Web Services (AWS). Use at your own risk. For official AWS-supported tooling, refer to the [AWS documentation](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/emr-eks.html).

## License

Apache-2.0
