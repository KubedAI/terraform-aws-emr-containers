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
    Example = "existing-cloudwatch-log-group"
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
# Example External CloudWatch Log Group (BYO)
#############################################
resource "aws_cloudwatch_log_group" "emr" {
  name              = "/emr-on-eks/${var.eks_cluster_name}/ml-team"
  retention_in_days = 90

  tags = var.tags
}

#############################################
# Module
#############################################
module "emr_on_eks" {
  source = "../../"

  eks_cluster_name = var.eks_cluster_name

  teams = {
    ml-team = {
      s3_bucket_arns              = ["arn:aws:s3:::my-ml-data"]
      create_cloudwatch_log_group = false
      cloudwatch_log_group_name   = aws_cloudwatch_log_group.emr.name
      tags = {
        Team = "ml-team"
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

output "existing_log_group_arn" {
  description = "The externally managed CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.emr.arn
}
