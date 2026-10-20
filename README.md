# PulseWatch Infrastructure & AWS EKS Deployment

Production-grade Infrastructure as Code (IaC) with **Terraform** and **Helm Charts** to deploy the [PulseWatch Uptime Monitoring Platform](https://github.com/paranietharan/pulsewatch) onto **Amazon Web Services (AWS) Elastic Kubernetes Service (EKS)**.

---

## 🏗️ Architecture Overview

The infrastructure provisions a secure, highly available, and scalable microservice topology:

```
                                  [ Internet / Clients ]
                                             │
                                     [ AWS Route 53 ]
                                             │
                              [ AWS Application Load Balancer ]
                                             │
                ┌────────────────────────────┴────────────────────────────┐
                ▼                                                         ▼
     [ pulse-watch-web ]                                         [ pulsewatch-api ]
     (Next.js Frontend: 3000)                                   (Go REST API: 8080)
                                                                          │
  ┌──────────────────────────────┬────────────────────────────────────────┼───────────────────────┐
  │                              │                                        │                       │
  ▼                              ▼                                        ▼                       ▼
[ pulsewatch-scheduler ]  [ pulsewatch-probe-worker ]  [ pulsewatch-notification-service ]  [ Migrator Job ]
(Cron sweep: 1 replica)   (Stateless Pool: Autoscaled) (Email / Webhook Dispatcher)         (Pre-install Hook)
  │                              │                                        │                       │
  │                              └───────────────┬────────────────────────┘                       │
  │                                              ▼                                                │
  │                                     [ RabbitMQ Broker ]                                       │
  │                                     (In-Cluster / Amazon MQ)                                  │
  │                                              │                                                │
  └──────────────────────────────────────────────┴────────────────────────────────────────────────┘
                                                 │
                                                 ▼
                                     [ AWS RDS PostgreSQL 16 ]
                                     (Multi-AZ / Automated Backups)
```

### Components Provisioned

| Category | Component | Description |
|---|---|---|
| **Networking** | AWS VPC (`10.0.0.0/16`) | 3 Public Subnets, 3 Private Application Subnets, 3 Database Subnets across 3 Availability Zones with NAT Gateway & Internet Gateway |
| **Compute** | AWS EKS Cluster (`1.30`) | Managed control plane with AWS Managed Node Group (gp3 encrypted EBS, autoscaling 2–6 nodes) |
| **Identity & IAM** | IAM IRSA (OIDC) | Least-privilege IAM roles for EBS CSI driver, AWS Load Balancer Controller, and application pods |
| **Database** | AWS RDS PostgreSQL 16 | Dedicated RDS PostgreSQL in isolated DB subnets with security group restricting ingress to EKS nodes |
| **Registries** | AWS ECR (6 Repositories) | Private Docker repositories with vulnerability scanning on push and 30-day lifecycle retention policies |
| **Ingress** | AWS Load Balancer Controller | Automatic provisioning and management of AWS Application Load Balancer with SSL termination |
| **Orchestration**| Helm Chart (`helm/pulsewatch`) | Deployments, Services, ConfigMaps, Secrets, Ingress, HPAs, and Pre-Install Migration Hooks |

---

## 📁 Repository Structure

```
pulsewatch-infra/
├── terraform/                       # Terraform Infrastructure as Code
│   ├── versions.tf                  # Provider versions (AWS, Kubernetes, Helm)
│   ├── variables.tf                 # Configurable deployment inputs & defaults
│   ├── vpc.tf                       # Multi-AZ VPC, subnets, NAT, and route tables
│   ├── eks.tf                       # EKS cluster, node groups, security groups, OIDC
│   ├── iam.tf                       # IRSA roles (EBS CSI & ALB Controller)
│   ├── iam_alb_policy.json          # AWS Load Balancer Controller IAM policy
│   ├── rds.tf                       # RDS PostgreSQL 16 instance & parameter group
│   ├── ecr.tf                       # ECR container repositories & lifecycle rules
│   ├── helm.tf                      # AWS Load Balancer Controller release
│   ├── outputs.tf                   # Cluster endpoints, DB connection string, ECR URLs
│   └── terraform.tfvars.example     # Sample variables file
├── helm/
│   └── pulsewatch/                  # PulseWatch Kubernetes Helm Chart
│       ├── Chart.yaml               # Chart metadata & version
│       ├── values.yaml              # Production defaults & full configuration
│       ├── values-prod.yaml         # High-traffic production overrides
│       └── templates/
│           ├── _helpers.tpl         # Template naming and connection string helpers
│           ├── serviceaccount.yaml  # ServiceAccount with IRSA annotations
│           ├── secrets.yaml         # Sensitive credentials (DB, RabbitMQ, JWT, SMTP)
│           ├── configmap.yaml       # Shared non-sensitive environment variables
│           ├── job-migrator.yaml    # Pre-install / pre-upgrade database migration hook
│           ├── deployment-api.yaml  # REST API deployment with /health probes
│           ├── service-api.yaml     # ClusterIP service for API (port 8080)
│           ├── hpa-api.yaml         # HorizontalPodAutoscaler for API
│           ├── deployment-web.yaml  # Next.js web frontend deployment
│           ├── service-web.yaml     # ClusterIP service for Web (port 80 -> 3000)
│           ├── deployment-scheduler.yaml    # Single-replica scheduler daemon
│           ├── deployment-probe-worker.yaml # Concurrent probe workers
│           ├── hpa-probe-worker.yaml        # HorizontalPodAutoscaler for workers
│           ├── deployment-notification-service.yaml # Alert dispatcher
│           ├── statefulset-rabbitmq.yaml    # In-cluster RabbitMQ with gp3 PVC
│           ├── service-rabbitmq.yaml        # RabbitMQ AMQP (5672) & UI (15672) services
│           └── ingress.yaml         # AWS ALB Ingress with host/path routing & TLS
├── docker/
│   └── Dockerfile.web               # Production multi-stage Dockerfile for pulse-watch-web
├── scripts/
│   ├── build-and-push.sh            # Builds and pushes all 6 microservices to AWS ECR
│   └── deploy.sh                    # Upgrades / installs the PulseWatch Helm release
└── .github/
    └── workflows/
        └── deploy.yml               # GitHub Actions CI/CD pipeline
```

---

## 🚀 Step-by-Step Deployment Guide

### Prerequisites
Ensure the following CLI tools are installed on your workstation:
- **AWS CLI v2** (`brew install awscli`) configured via `aws configure`
- **Terraform** (`brew install hashicorp/tap/terraform` or `opentofu`)
- **kubectl** (`brew install kubectl`)
- **Helm v3** (`brew install helm`)
- **Docker** (`brew install --cask docker`)

---

### Step 1: Provision AWS Infrastructure with Terraform

1. Navigate to the terraform directory:
   ```bash
   cd terraform
   ```

2. Copy the example variables and customize:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   *Edit `terraform.tfvars` with your preferred AWS region, domain name, and ACM Certificate ARN.*

3. Initialize and plan:
   ```bash
   terraform init
   terraform plan -out=tfplan
   ```

4. Apply the infrastructure:
   ```bash
   terraform apply tfplan
   ```

5. Connect your local `kubectl` to the new EKS cluster:
   ```bash
   # Run the command output by Terraform:
   aws eks update-kubeconfig --region us-east-1 --name pulsewatch-eks

   # Verify worker nodes are Ready:
   kubectl get nodes
   ```

6. Note down the Terraform outputs:
   ```bash
   terraform output database_url
   terraform output rds_address
   terraform output ecr_repository_urls
   ```

---

### Step 2: Build and Push Docker Images to AWS ECR

1. Run the automated build and push script:
   ```bash
   cd ..
   export AWS_REGION="us-east-1"
   export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
   export IMAGE_TAG="latest"

   ./scripts/build-and-push.sh
   ```

This builds and pushes all 6 images:
- `${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/pulsewatch-api:latest`
- `${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/pulsewatch-web:latest`
- `${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/pulsewatch-scheduler:latest`
- `${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/pulsewatch-probe-worker:latest`
- `${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/pulsewatch-notification-service:latest`
- `${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/pulsewatch-db-migrator:latest`

---

### Step 3: Configure Helm Values & Deploy

1. Edit `helm/pulsewatch/values.yaml` (or create a custom `my-values.yaml`):
   ```yaml
   database:
     host: "<RDS_ENDPOINT_FROM_TERRAFORM_OUTPUT>"
     port: 5432
     dbName: "pulsewatch"
     user: "pulsewatch_admin"
     password: "<YOUR_RDS_PASSWORD>"
     sslmode: "require"

   rabbitmq:
     auth:
       username: "pulsewatch"
       password: "<STRONG_RABBITMQ_PASSWORD>"

   api:
     image:
       repository: "<AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/pulsewatch-api"
       tag: "latest"
     jwtSecret: "<MIN_32_CHAR_JWT_SECRET>"
     publicUrl: "https://api.pulsewatch.yourdomain.com"

   web:
     image:
       repository: "<AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/pulsewatch-web"
       tag: "latest"
     publicUrl: "https://pulsewatch.yourdomain.com"

   ingress:
     enabled: true
     annotations:
       alb.ingress.kubernetes.io/certificate-arn: "<YOUR_ACM_CERTIFICATE_ARN>"
     hosts:
       - host: "pulsewatch.yourdomain.com"
         paths:
           - path: "/"
             pathType: "Prefix"
             service: "web"
             port: 80
       - host: "api.pulsewatch.yourdomain.com"
         paths:
           - path: "/"
             pathType: "Prefix"
             service: "api"
             port: 8080
   ```

2. Deploy the Helm release:
   ```bash
   ./scripts/deploy.sh
   ```
   *The Helm hook will automatically run the schema migrator job first, create all database tables, and then roll out the application pods.*

---

### Step 4: Verification & DNS Setup

1. Check running pods and services:
   ```bash
   kubectl get pods -n pulsewatch
   kubectl get svc -n pulsewatch
   ```

2. Inspect the AWS Application Load Balancer created by Ingress:
   ```bash
   kubectl get ingress -n pulsewatch
   ```
   *Note the `ADDRESS` field (e.g. `k8s-pulsewat-pulsewat-xxxxxx.us-east-1.elb.amazonaws.com`).*

3. Create DNS CNAME or Alias records in Route 53 (or Cloudflare / Namecheap):
   - `pulsewatch.yourdomain.com` ➔ `k8s-pulsewat-pulsewat-xxxxxx.us-east-1.elb.amazonaws.com`
   - `api.pulsewatch.yourdomain.com` ➔ `k8s-pulsewat-pulsewat-xxxxxx.us-east-1.elb.amazonaws.com`

4. Verify REST API Health:
   ```bash
   curl -i https://api.pulsewatch.yourdomain.com/health
   # Returns: HTTP/2 200 OK
   ```

5. Open `https://pulsewatch.yourdomain.com` in your browser to access the PulseWatch dashboard!

---

## 🧹 Tear Down

To cleanly destroy all provisioned AWS cloud infrastructure:

```bash
# 1. Uninstall Helm release (deletes ALB and in-cluster PVCs)
helm uninstall pulsewatch -n pulsewatch

# 2. Destroy Terraform resources
cd terraform
terraform destroy -auto-approve
```
