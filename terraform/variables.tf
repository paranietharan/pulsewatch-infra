variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "us-east-1"
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
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
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
  default     = ["t3.large"]
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
  default     = 50
}

# ------------------------------------------------------------------------------
# AWS RDS PostgreSQL Variables
# ------------------------------------------------------------------------------
variable "enable_rds" {
  description = "Set to true to provision AWS RDS PostgreSQL. Set to false to run PostgreSQL inside EKS via Helm"
  type        = bool
  default     = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.medium"
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
  default     = 100
}

variable "db_multi_az" {
  description = "Enable Multi-AZ replication for production database failover"
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Automated daily snapshot retention period in days"
  type        = number
  default     = 7
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
# PulseWatch Helm Release Variables
# ------------------------------------------------------------------------------
variable "deploy_pulsewatch_helm" {
  description = "Set to true to automatically deploy the PulseWatch Helm chart using Terraform"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Primary domain name for PulseWatch (e.g. pulsewatch.dev or example.com)"
  type        = string
  default     = "example.com"
}

variable "acm_certificate_arn" {
  description = "ARN of an existing AWS Certificate Manager (ACM) TLS certificate for ALB Ingress (optional)"
  type        = string
  default     = ""
}
