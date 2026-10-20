# PulseWatch Deployment Platform Implementation Plan

## 1. Executive Summary & Infrastructure Architecture

The PulseWatch deployment platform is built using **Terraform** for Infrastructure as Code (IaC) and **Helm** for Kubernetes workload orchestration on **Amazon Web Services (AWS) Elastic Kubernetes Service (EKS)**. It isolates environments using Kubernetes namespaces (`staging` and `production`) on a multi-AZ cluster.

### Architecture Overview

- **Compute:** AWS EKS Cluster (Kubernetes 1.30) with managed node group spanning 3 Availability Zones (`t3.large`, gp3 storage, node autoscaling).
- **Networking:** Dedicated VPC (`10.0.0.0/16`) with 3 Public subnets, 3 Private Application subnets, and 3 Isolated Database subnets with Internet Gateway and NAT Gateway.
- **Identity & Security:** IAM OIDC provider with IRSA (IAM Roles for Service Accounts) for AWS Load Balancer Controller and EBS CSI driver. Pod-level least-privilege `securityContext` (`runAsNonRoot: true`, `allowPrivilegeEscalation: false`, drop all Linux capabilities).
- **Relational Storage:** AWS RDS PostgreSQL 16 in isolated subnets, encrypted at rest with AWS KMS, enforced in-transit TLS (`rds.force_ssl = 1`), and automatic daily snapshot retention.
- **Container Registry:** 6 private AWS ECR repositories with vulnerability scan-on-push and 30-day untagged image retention lifecycle policy.
- **Message Broker:** High-availability in-cluster RabbitMQ StatefulSet with dynamic EBS gp3 storage volume claims and headless service.
- **Ingress & TLS:** AWS Application Load Balancer (ALB) via AWS Load Balancer Controller with host/path routing and SSL/TLS termination.
- **Database Migrations:** Automated pre-install/pre-upgrade Helm Job hook running `pulsewatch-db-migrator`.

---

## 2. Infrastructure & Deployment Platform Audit

| Component | Status | Verification Result |
|---|---|---|
| **Terraform Core** | Implemented & Validated | `terraform init -backend=false && terraform validate` passed cleanly. `terraform fmt -check` passed. |
| **VPC & Subnets** | Implemented | 3 Public, 3 Private, 3 DB subnets across 3 AZs. Tagged for Kubernetes ALB discovery. |
| **EKS & IAM** | Implemented | Control plane 1.30, OIDC IRSA provider, managed node groups, least-privilege IAM roles. |
| **RDS PostgreSQL 16** | Implemented & Hardened | Multi-AZ ready, enforced SSL (`rds.force_ssl = 1`), environment-based deletion protection. |
| **ECR Registries** | Implemented | 6 repositories for all services with scan on push and image lifecycle rules. |
| **Remote State Backend** | Implemented | Bootstrap code in `terraform/backend_setup/` for encrypted S3 bucket and DynamoDB locking table. |
| **Namespaces & Quotas** | Implemented | `staging` and `production` namespaces with resource quotas. |
| **Helm Chart (`pulsewatch`)** | Implemented & Validated | `helm lint` and `helm template` render without errors for staging and production. |
| **Pod Security Contexts** | Implemented & Hardened | `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `drop: [ALL]` applied to all workloads. |
| **CI/CD Workflows** | Implemented | `ci.yml` (Terraform/Helm lint), `deploy.yml` (Helm rollout), `terraform.yml` (Plan/Apply with S3 state). |
| **Automation Scripts** | Implemented | `scripts/build-and-push.sh` and `scripts/deploy.sh` for repeatable deployments. |
| **Operational Runbooks** | Implemented | Documented zero-downtime rollbacks, PITR database restores, and queue diagnostics. |

---

## 3. Verification Commands & Acceptance Criteria

```bash
# 1. Terraform code validation
cd pulsewatch-infra/terraform
terraform init -backend=false
terraform fmt -check
terraform validate

# 2. Remote state bootstrap validation
cd pulsewatch-infra/terraform/backend_setup
terraform init -backend=false
terraform fmt -check
terraform validate

# 3. Helm chart linting across all value profiles
cd pulsewatch-infra
helm lint helm/pulsewatch
helm lint helm/pulsewatch -f helm/pulsewatch/values-staging.yaml
helm lint helm/pulsewatch -f helm/pulsewatch/values-prod.yaml

# 4. Helm template rendering validation
helm template pulsewatch-staging helm/pulsewatch -f helm/pulsewatch/values-staging.yaml > /dev/null
helm template pulsewatch-production helm/pulsewatch -f helm/pulsewatch/values-prod.yaml > /dev/null
```
