#############################################
# Deploy EMR on EKS WITHOUT Kubernetes API Access
#############################################
#
# This example demonstrates how to use the module when the caller does NOT have
# access to the Kubernetes API (e.g. a data-platform team that provisions EMR
# virtual clusters while a separate platform/SRE team manages EKS).
#
# Prerequisites managed by the platform team:
#   1. EKS cluster exists (spark-on-eks)
#   2. Namespace pre-created (emr-datateam-a)
#   3. EKS Access Entries configured for EMR (creates RBAC automatically)
#
# With create_namespace = false and create_emr_rbac = false (default), no
# kubernetes_* resources are created, so the Kubernetes API is never called.
#
# The kubernetes provider block below uses a placeholder — Terraform requires
# the provider to be initialised because the module declares it, but since no
# Kubernetes resources appear in the plan, it never actually connects.

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
# Providers
#############################################
provider "aws" {
  region = var.region
}

# Placeholder — no Kubernetes resources are created when create_namespace = false
# and create_emr_rbac = false, so this provider never makes API calls.
provider "kubernetes" {
  host = "https://localhost"
}

provider "encode" {}

#############################################
# Module
#############################################
module "emr_on_eks" {
  source = "../../"

  eks_cluster_name                 = "spark-on-eks"
  enable_cloudwatch_kms_encryption = false

  teams = {
    datateam-a = {
      create_namespace = false
      namespace        = "emr-datateam-a" # pre-created by the platform team
      s3_bucket_arns   = ["arn:aws:s3:::<ENTER_BUCKET_NAME>"]
      tags = {
        Team = "datateam-a"
      }
    }
  }

  tags = var.tags
}
