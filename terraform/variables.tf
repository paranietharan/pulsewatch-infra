variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Target deployment environment (e.g. dev, staging, prod)"
  type        = string
  default     = "prod"
}

# ------------------------------------------------------------------------------
# VPC Networking Variables
# ------------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the PulseWatch VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to span across"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (ALB / Ingress & NAT)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private application subnets (EKS nodes & pods)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for isolated database subnets (RDS PostgreSQL)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
}

variable "single_nat_gateway" {
  description = "Provision a single NAT Gateway across all AZs to minimize AWS costs (set to false for high-availability multi-AZ NAT)"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# EKS Cluster Variables
# ------------------------------------------------------------------------------
variable "cluster_name" {
  description = "Name of the AWS EKS Cluster"
  type        = string
  default     = "pulsewatch-eks"
}

variable "cluster_version" {
  description = "Kubernetes control plane version"
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_group_desired_size" {
  description = "Initial desired worker node capacity"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum worker node capacity for autoscaling"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum worker node capacity for autoscaling"
  type        = number
  default     = 6
}

variable "node_disk_size" {
  description = "Root disk size in GiB for each worker node"
  type        = number
  default     = 20
}

# ------------------------------------------------------------------------------
# AWS RDS PostgreSQL Variables
# ------------------------------------------------------------------------------
variable "enable_rds" {
  description = "Set to true to provision AWS RDS PostgreSQL. Set to false to run PostgreSQL inside EKS via Helm"
  type        = bool
  default     = true
}

variable "db_engine_version" {
  description = "PostgreSQL engine version supported by RDS"
  type        = string
  default     = "16.9"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "PostgreSQL primary database name"
  type        = string
  default     = "pulsewatch"
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "pulsewatch_admin"
}

variable "db_password" {
  description = "PostgreSQL master password (leave empty to generate automatically)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GiB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum storage limit in GiB for RDS storage autoscaling"
  type        = number
  default     = 50
}

variable "db_multi_az" {
  description = "Enable Multi-AZ replication for production database failover"
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Automated daily snapshot retention period in days (0 disables automated snapshots, required for AWS Free Tier)"
  type        = number
  default     = 0
}

# ------------------------------------------------------------------------------
# ECR & Registry Variables
# ------------------------------------------------------------------------------
variable "enable_ecr" {
  description = "Provision AWS ECR repositories for PulseWatch microservices"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Kubernetes Namespaces & Multi-Environment Variables
# ------------------------------------------------------------------------------
variable "staging_namespace" {
  description = "Kubernetes namespace for the staging environment"
  type        = string
  default     = "staging"
}

variable "production_namespace" {
  description = "Kubernetes namespace for the production environment"
  type        = string
  default     = "production"
}

variable "enable_namespace_quotas" {
  description = "Apply resource quotas to staging and production namespaces to prevent resource starvation"
  type        = bool
  default     = false
}

variable "staging_db_name" {
  description = "PostgreSQL database name for staging environment"
  type        = string
  default     = "pulsewatch_staging"
}

# ------------------------------------------------------------------------------
# PulseWatch Helm Release Variables
# ------------------------------------------------------------------------------
variable "deploy_staging_helm" {
  description = "Set to true to deploy PulseWatch Helm release to the staging namespace using Terraform"
  type        = bool
  default     = false
}

variable "deploy_production_helm" {
  description = "Set to true to deploy PulseWatch Helm release to the production namespace using Terraform"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Base domain name for PulseWatch (optional: leave empty if custom domain is not yet configured)"
  type        = string
  default     = ""
}

variable "staging_domain_name" {
  description = "Domain name for staging environment (e.g. staging.pulsewatch.example.com)"
  type        = string
  default     = ""
}

variable "production_domain_name" {
  description = "Domain name for production environment (e.g. pulsewatch.example.com)"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ARN of an existing AWS Certificate Manager (ACM) TLS certificate for ALB Ingress (optional)"
  type        = string
  default     = ""
}

