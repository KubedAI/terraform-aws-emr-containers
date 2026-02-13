# data.tf — AWS account and partition context
# These data sources are referenced across IAM, CloudWatch, and pod-identity files.

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}
