# PulseWatch Infrastructure (`pulsewatch-infra`)

Terraform configurations, Helm charts, and deployment scripts for running the [PulseWatch](https://github.com/paranietharan/pulsewatch) uptime monitoring platform on **AWS EKS**.

---

## Repository Structure

```
pulsewatch-infra/
├── terraform/              # AWS infrastructure provisioning
│   ├── vpc.tf              # Multi-AZ VPC, public/private subnets, NAT gateway
│   ├── eks.tf              # Amazon EKS cluster and managed node groups
│   ├── rds.tf              # Amazon RDS PostgreSQL instance and security groups
│   ├── ecr.tf              # Amazon ECR repositories for all PulseWatch containers
│   ├── iam.tf              # IAM roles and AWS Load Balancer Controller policies
│   ├── helm.tf             # Cluster add-ons (AWS Load Balancer Controller, metrics)
│   ├── namespaces.tf       # Kubernetes staging and production namespaces
│   └── backend_setup/      # S3 bucket and DynamoDB table setup for Terraform state
├── helm/
│   └── pulsewatch/         # Umbrella Helm chart for PulseWatch services
│       ├── values.yaml     # Default production values (HPA, resources, probes)
│       └── templates/      # Deployments, Services, HPA, Ingress, Migrator hook
└── scripts/
    ├── build-and-push.sh   # Builds Docker images and pushes them to Amazon ECR
    └── deploy.sh           # Runs Helm upgrades for staging or production namespaces
```

---

## What Gets Provisioned

1. **Networking (`terraform/vpc.tf`)**: VPC across multiple availability zones with public subnets for the Application Load Balancer and private subnets for EKS worker nodes and RDS.
2. **Kubernetes Cluster (`terraform/eks.tf`, `terraform/iam.tf`)**: Managed Amazon EKS cluster with IAM Roles for Service Accounts (IRSA) and the AWS Load Balancer Controller installed via Helm.
3. **Database & Container Registry (`terraform/rds.tf`, `terraform/ecr.tf`)**: Managed Amazon RDS PostgreSQL database and private ECR repositories for `pulsewatch-api`, `pulsewatch-scheduler`, `pulsewatch-probe-worker`, `pulsewatch-notification-service`, `pulsewatch-web`, and `pulsewatch-db-migrator`.
4. **Application Workloads (`helm/pulsewatch`)**:
   - Pre-install/pre-upgrade Helm hook job (`migrator`) that applies SQL migrations before rolling out new pods.
   - Kubernetes Deployments and HorizontalPodAutoscalers (`HPA`) for the API and probe worker pool.
   - In-cluster RabbitMQ StatefulSet with `gp3` persistent volume claims (or external AMQP broker configuration).
   - AWS ALB Ingress routing traffic to the Next.js web dashboard and Go REST API.

---

## Provisioning & Deployment

### Step 1: Provision AWS Resources with Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS region, cluster name, and DB credentials

terraform init
terraform apply
```

### Step 2: Configure `kubectl`
```bash
aws eks update-kubeconfig --region ap-south-1 --name pulsewatch-eks
```

### Step 3: Build & Push Container Images to ECR
```bash
cd ..
./scripts/build-and-push.sh
```

### Step 4: Deploy to Staging or Production via Helm
```bash
./scripts/deploy.sh staging
./scripts/deploy.sh production
```

---

## Teardown (Stop AWS Billing)

When tearing down the environment to avoid ongoing EKS, NAT Gateway, and RDS charges:

### 1. Create an RDS Snapshot (Optional)
```bash
aws rds create-db-snapshot \
  --db-instance-identifier pulsewatch-eks-postgres \
  --db-snapshot-identifier "pulsewatch-backup-$(date +%Y%m%d)" \
  --region ap-south-1
```

### 2. Remove Helm Releases & Load Balancers First
Uninstalling the Helm releases and deleting PVCs ensures the AWS Load Balancer Controller removes the ALB and EBS volumes before Terraform deletes the VPC:
```bash
helm uninstall pulsewatch-production -n production 2>/dev/null || true
helm uninstall pulsewatch-staging -n staging 2>/dev/null || true
kubectl delete pvc --all -n production 2>/dev/null || true
kubectl delete pvc --all -n staging 2>/dev/null || true
sleep 45
```

### 3. Destroy Terraform Resources
```bash
cd terraform
terraform destroy
```
