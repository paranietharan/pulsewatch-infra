output "aws_region" {
  description = "AWS region deployed to"
  value       = var.aws_region
}

output "cluster_name" {
  description = "EKS Cluster Name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS Cluster API Endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS Cluster CA Data (Base64)"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "configure_kubectl" {
  description = "Command to configure kubectl credentials locally"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "rds_endpoint" {
  description = "RDS PostgreSQL Host Address & Port"
  value       = var.enable_rds ? aws_db_instance.postgres[0].endpoint : "None"
}

output "rds_address" {
  description = "RDS PostgreSQL Host FQDN"
  value       = var.enable_rds ? aws_db_instance.postgres[0].address : "None"
}

output "rds_database_name" {
  description = "RDS PostgreSQL Database Name"
  value       = var.db_name
}

output "rds_username" {
  description = "RDS PostgreSQL Master Username"
  value       = var.db_username
}

output "rds_password" {
  description = "RDS PostgreSQL Master Password"
  value       = local.db_password
  sensitive   = true
}

output "database_url" {
  description = "Full PostgreSQL connection URI for PulseWatch services"
  value       = var.enable_rds ? "postgres://${var.db_username}:${local.db_password}@${aws_db_instance.postgres[0].address}:5432/${var.db_name}?sslmode=require" : ""
  sensitive   = true
}

output "ecr_repository_urls" {
  description = "Map of ECR repository URLs for Docker image publishing"
  value = {
    for k, v in aws_ecr_repository.repos : k => v.repository_url
  }
}

output "alb_controller_role_arn" {
  description = "IAM Role ARN for AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "staging_namespace" {
  description = "Kubernetes namespace for Staging environment"
  value       = var.staging_namespace
}

output "production_namespace" {
  description = "Kubernetes namespace for Production environment"
  value       = var.production_namespace
}

output "staging_domain" {
  description = "Domain name for Staging environment"
  value       = local.staging_domain
}

output "production_domain" {
  description = "Domain name for Production environment"
  value       = local.production_domain
}

output "staging_database_url" {
  description = "PostgreSQL connection URI for Staging environment"
  value       = var.enable_rds ? "postgres://${var.db_username}:${local.db_password}@${aws_db_instance.postgres[0].address}:5432/${var.staging_db_name}?sslmode=require" : ""
  sensitive   = true
}

output "production_database_url" {
  description = "PostgreSQL connection URI for Production environment"
  value       = var.enable_rds ? "postgres://${var.db_username}:${local.db_password}@${aws_db_instance.postgres[0].address}:5432/${var.db_name}?sslmode=require" : ""
  sensitive   = true
}

output "check_staging_pods_cmd" {
  description = "Command to inspect staging pods"
  value       = "kubectl get pods -n ${var.staging_namespace}"
}

output "check_production_pods_cmd" {
  description = "Command to inspect production pods"
  value       = "kubectl get pods -n ${var.production_namespace}"
}

