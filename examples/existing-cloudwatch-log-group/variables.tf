variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "eks_cluster_name" {
  description = "Name of the existing EKS cluster"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Example = "existing-cloudwatch-log-group"
  }
}
