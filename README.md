# terraform-aws-emr-containers

Terraform module for provisioning [Amazon EMR on EKS](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/emr-eks.html) virtual clusters with multi-tenancy support.

[EMR on EKS](https://aws.amazon.com/emr/features/eks/) lets you run [Apache Spark](https://spark.apache.org/) jobs on [Amazon EKS](https://aws.amazon.com/eks/) clusters without managing separate EMR infrastructure. This module automates the per-team setup that EMR on EKS requires: for each team defined in the `teams` map, it creates a dedicated [Kubernetes namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/), [EMR virtual cluster](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/virtual-cluster.html), [IAM execution role](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/iam-execution-role.html), [CloudWatch log group](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html), and [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html) associations.

### Architecture

```
EKS Cluster
  ├── Team A Namespace
  │     ├── EMR Virtual Cluster
  │     ├── Kubernetes Role / RoleBinding (optional — legacy aws-auth only)
  │     ├── Pod Identity Associations (client, driver, executor)
  │     └── IAM Execution Role ──► S3, CloudWatch Logs, Glue
  ├── Team B Namespace
  │     └── ...
  └── Team N Namespace
        └── ...
```

## Features

- Multi-tenancy via a `teams` map — define as many teams as needed
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html) associations (not IRSA) with automatic base36 service account naming
- Conditional namespace creation (`create_namespace = false` for pre-existing namespaces)
- Optional namespace-scoped [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) for EMR on EKS (legacy `aws-auth` clusters only; `create_emr_rbac = false` by default)
- Conditional IAM role creation (`create_iam_role = false` to bring your own role)
- Conditional [CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/WhatIsCloudWatchLogs.html) log group creation (`create_cloudwatch_log_group = false` to bring your own)
- Scoped IAM policies: [S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html) (bucket/object split with optional prefix scoping), CloudWatch Logs, [Glue catalog](https://docs.aws.amazon.com/glue/latest/dg/catalog-and-crawler.html)
- CloudWatch Logs encryption with customer-managed [KMS](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html) keys (module-managed key by default)
- Optional [IAM permissions boundary](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html) on created execution roles
- Optional pod identity trust-policy hardening with `aws:SourceAccount` condition
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
| [time](https://registry.terraform.io/providers/hashicorp/time) | >= 0.9 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.28 |
| kubernetes | >= 2.38 |
| encode | 0.3.0-beta.1 |
| time | >= 0.9 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `eks_cluster_name` | Name of the existing EKS cluster | `string` | n/a | yes |
| `tags` | Tags to apply to all resources | `map(string)` | `{}` | no |
| `enable_pod_identity_trust_conditions` | Add source-account trust condition to pod identity roles | `bool` | `true` | no |
| `iam_role_permissions_boundary` | Default permissions boundary ARN for created IAM roles | `string` | `null` | no |
| `enable_cloudwatch_kms_encryption` | Encrypt module-managed CloudWatch log groups with CMK (default: AWS default encryption) | `bool` | `false` | no |
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
| `create_emr_rbac` | Whether to create namespace-scoped Kubernetes Role and RoleBinding for EMR on EKS (only needed for legacy `aws-auth` clusters) | `bool` | `false` |
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

[EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html) is the recommended way to grant AWS permissions to Kubernetes pods, replacing the older [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) approach. EMR on EKS creates Kubernetes service accounts with the naming pattern:

```
emr-containers-sa-spark-{ROLE}-{ACCOUNT_ID}-{BASE36_ENCODED_ROLE_NAME}
```

Where `ROLE` is one of `client`, `driver`, or `executor`. The module uses the [`justenwalker/encode`](https://registry.terraform.io/providers/justenwalker/encode/latest) provider to compute the base36 encoding, matching the algorithm used by the AWS CLI (`awscli/customizations/emrcontainers/base36.py`).

### Kubernetes RBAC

There are two approaches for granting EMR on EKS the Kubernetes permissions it needs:

**EKS Access Entries (recommended, EKS 1.23+):** When your cluster uses [EKS access entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html) for authentication, EMR automatically creates the necessary namespace-scoped RBAC resources when you call [`CreateVirtualCluster`](https://docs.aws.amazon.com/emr-on-eks/latest/APIReference/API_CreateVirtualCluster.html). No manual Kubernetes Role or RoleBinding is needed. This is the default behavior of this module (`create_emr_rbac = false`).

**Legacy `aws-auth` ConfigMap:** If your cluster still uses the [`aws-auth` ConfigMap](https://docs.aws.amazon.com/eks/latest/userguide/auth-configmap.html) for authentication, you must manually create the RBAC resources. Set `create_emr_rbac = true` per team to have the module create a namespace-scoped [`Role` and `RoleBinding`](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) named `emr-containers` matching the [EMR on EKS cluster access setup](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/setting-up-cluster-access.html). You must also map the `emr-containers` Kubernetes user in the `aws-auth` ConfigMap separately.

Note: this module does not manage EKS authentication mappings (`aws-auth` ConfigMap or access entries). Configure those separately in your EKS cluster module.

### IAM Role Naming

Default IAM role names use an MD5-based short hash (`emr-{hash6}`) to keep generated service account names compact for downstream policy/selectors that may enforce tighter limits. Override with `iam_role_name` if you need a specific naming convention.

### Security Defaults

- CloudWatch log groups use AWS default encryption; optionally encrypt with a customer-managed [KMS key](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html) via `enable_cloudwatch_kms_encryption`.
- Pod identity trust policies include an [`aws:SourceAccount`](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html#condition-keys-sourceaccount) condition by default.
- S3 access can be narrowed to key prefixes using `s3_object_prefixes`.
- IAM role [permissions boundaries](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html) can be enforced globally or per team.

## Prerequisites: IAM Permissions for Deployment

The Terraform execution role or user deploying this module needs the following least-privilege IAM permissions against your existing EKS cluster:

**EKS** (for [Access Entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html) — used by `CreateVirtualCluster`):
- `eks:CreateAccessEntry`, `eks:DescribeAccessEntry`, `eks:DeleteAccessEntry`
- `eks:ListAssociatedAccessPolicies`, `eks:AssociateAccessPolicy`, `eks:DisassociateAccessPolicy`

**EKS** (for [Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html) associations):
- `eks:CreatePodIdentityAssociation`, `eks:DeletePodIdentityAssociation`
- `eks:DescribePodIdentityAssociation`, `eks:ListPodIdentityAssociations`

**EMR on EKS**:
- `emr-containers:CreateVirtualCluster`, `emr-containers:DeleteVirtualCluster`
- `emr-containers:DescribeVirtualCluster`, `emr-containers:ListVirtualClusters`

**IAM** (for creating [execution roles](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/iam-execution-role.html)):
- `iam:CreateRole`, `iam:DeleteRole`, `iam:GetRole`, `iam:PassRole`, `iam:TagRole`
- `iam:PutRolePolicy`, `iam:DeleteRolePolicy`, `iam:GetRolePolicy`
- `iam:AttachRolePolicy`, `iam:DetachRolePolicy`, `iam:ListAttachedRolePolicies`
- `iam:ListRolePolicies`, `iam:ListInstanceProfilesForRole`

**CloudWatch Logs**:
- `logs:CreateLogGroup`, `logs:DeleteLogGroup`, `logs:DescribeLogGroups`
- `logs:PutRetentionPolicy`, `logs:TagResource`, `logs:ListTagsForResource`

**KMS** (only if `enable_cloudwatch_kms_encryption = true`):
- `kms:CreateKey`, `kms:DescribeKey`, `kms:GetKeyPolicy`, `kms:GetKeyRotationStatus`
- `kms:PutKeyPolicy`, `kms:EnableKeyRotation`, `kms:TagResource`
- `kms:ScheduleKeyDeletion`, `kms:ListResourceTags`

**Kubernetes** (via kubeconfig / EKS auth token):
- Create/delete namespaces (if `create_namespace = true`)
- Create/delete Roles, RoleBindings in team namespaces (if `create_emr_rbac = true`)

## Disclaimer

This is an independent open-source project maintained by [KubedAI](https://github.com/KubedAI) and is **not** affiliated with, sponsored by, or officially supported by Amazon Web Services (AWS). Use at your own risk. For official AWS-supported tooling, refer to the [AWS documentation](https://docs.aws.amazon.com/emr/latest/EMR-on-EKS-DevelopmentGuide/emr-eks.html).

## License

Apache-2.0
