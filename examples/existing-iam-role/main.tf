#############################################
# Terraform Settings
#############################################
terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38"
    }
    encode = {
      source  = "justenwalker/encode"
      version = "0.3.0-beta.1"
    }
  }
}

#############################################
# Input Variables
#############################################
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
    Example = "existing-iam-role"
  }
}

#############################################
# Data Sources
#############################################
data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.eks_cluster_name
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

#############################################
# Providers
#############################################
provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "encode" {}

#############################################
# Example External IAM Role (BYO)
#############################################
resource "aws_iam_role" "emr_execution" {
  name               = "my-emr-execution-role"
  assume_role_policy = data.aws_iam_policy_document.trust.json

  tags = var.tags
}

resource "aws_iam_role_policy" "emr_s3" {
  name = "s3-access"
  role = aws_iam_role.emr_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::my-spark-data",
          "arn:aws:s3:::my-spark-data/*",
        ]
      }
    ]
  })
}

#############################################
# Module
#############################################
module "emr_on_eks" {
  source = "../../"

  eks_cluster_name = var.eks_cluster_name

  teams = {
    data-science = {
      create_iam_role       = false
      existing_iam_role_arn = aws_iam_role.emr_execution.arn
      tags = {
        Team = "data-science"
      }
    }
  }

  tags = var.tags
}

#############################################
# Outputs
#############################################
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
