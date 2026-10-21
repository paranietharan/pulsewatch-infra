terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Remote state backend in Amazon S3 with DynamoDB state locking
  backend "s3" {
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "pulsewatch-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "PulseWatch"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.main.name
}

provider "kubernetes" {
  host                   = try(aws_eks_cluster.main.endpoint, "")
  cluster_ca_certificate = try(base64decode(aws_eks_cluster.main.certificate_authority[0].data), "")
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = try(aws_eks_cluster.main.endpoint, "")
    cluster_ca_certificate = try(base64decode(aws_eks_cluster.main.certificate_authority[0].data), "")
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
