variable "eks_cluster_name" {
  description = "Name of the existing EKS cluster"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_pod_identity_trust_conditions" {
  description = "Whether to scope pod identity role trust policies with source-account and request-tag conditions"
  type        = bool
  default     = true
}

variable "iam_role_permissions_boundary" {
  description = "Optional IAM permissions boundary ARN applied to all created execution roles (can be overridden per team)"
  type        = string
  default     = null
}

variable "enable_cloudwatch_kms_encryption" {
  description = "Whether to encrypt module-managed CloudWatch log groups with a customer-managed KMS key. When false, log groups use the AWS default encryption."
  type        = bool
  default     = false
}

variable "cloudwatch_kms_key_id" {
  description = "Existing KMS key ARN to use for CloudWatch log group encryption. If null and encryption is enabled, the module creates a key."
  type        = string
  default     = null
}

variable "create_cloudwatch_kms_key" {
  description = "Whether to create a KMS key for CloudWatch log group encryption when cloudwatch_kms_key_id is null"
  type        = bool
  default     = true
}

variable "cloudwatch_kms_key_enable_rotation" {
  description = "Whether to enable automatic key rotation on the module-created CloudWatch KMS key"
  type        = bool
  default     = true
}

variable "cloudwatch_kms_key_deletion_window_in_days" {
  description = "Deletion window for the module-created CloudWatch KMS key"
  type        = number
  default     = 30

  validation {
    condition     = var.cloudwatch_kms_key_deletion_window_in_days >= 7 && var.cloudwatch_kms_key_deletion_window_in_days <= 30
    error_message = "cloudwatch_kms_key_deletion_window_in_days must be between 7 and 30."
  }
}

variable "cloudwatch_kms_key_description" {
  description = "Description for the module-created CloudWatch KMS key"
  type        = string
  default     = "KMS key for EMR on EKS CloudWatch Logs encryption"
}

variable "teams" {
  description = "Map of team configurations for EMR virtual clusters"
  type = map(object({
    namespace                      = optional(string)
    create_namespace               = optional(bool, true)
    create_emr_rbac                = optional(bool, true)
    create_iam_role                = optional(bool, true)
    iam_role_name                  = optional(string)
    iam_role_permissions_boundary  = optional(string)
    existing_iam_role_arn          = optional(string)
    s3_bucket_arns                 = optional(list(string), [])
    s3_object_prefixes             = optional(list(string), [])
    attach_glue_policy             = optional(bool, false)
    additional_iam_policy_arns     = optional(list(string), [])
    create_cloudwatch_log_group    = optional(bool, true)
    cloudwatch_log_group_name      = optional(string)
    cloudwatch_log_group_retention = optional(number, 30)
    tags                           = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for k, v in var.teams :
      v.create_iam_role != false || v.existing_iam_role_arn != null
    ])
    error_message = "Teams with create_iam_role = false must provide existing_iam_role_arn."
  }

  validation {
    condition = alltrue([
      for k, v in var.teams :
      v.create_namespace != false || v.namespace != null
    ])
    error_message = "Teams with create_namespace = false must provide namespace."
  }

  validation {
    condition = alltrue([
      for k, v in var.teams :
      v.create_cloudwatch_log_group != false || v.cloudwatch_log_group_name != null
    ])
    error_message = "Teams with create_cloudwatch_log_group = false must provide cloudwatch_log_group_name."
  }

  validation {
    condition = alltrue([
      for k, v in var.teams :
      length(v.s3_object_prefixes) == 0 || length(v.s3_bucket_arns) > 0
    ])
    error_message = "Teams using s3_object_prefixes must also provide s3_bucket_arns."
  }
}
