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
# Module
#############################################
module "emr_on_eks" {
  source = "../../"
  # To consume the module form Github, use the below source path and update the version as needed.
  # source = "git::https://github.com/KubedAI/terraform-aws-emr-containers.git?ref=v0.2.1"

  eks_cluster_name                 = var.eks_cluster_name
  enable_cloudwatch_kms_encryption = false

  teams = {
    analytics = {
      s3_bucket_arns     = ["arn:aws:s3:::analytics-bucket"]
      attach_glue_policy = true
      tags = {
        Team = "analytics"
      }
    }
    datascience = {
      s3_bucket_arns     = ["arn:aws:s3:::datascience-bucket"]
      attach_glue_policy = true
      tags = {
        Team = "datascience"
      }
    }
  }

  tags = var.tags
}
