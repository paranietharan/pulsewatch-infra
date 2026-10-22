# PulseWatch Infrastructure (AWS EKS & Helm)

This repository contains the Infrastructure as Code (Terraform) and Helm charts for PulseWatch.

---

### 🚀 Local Infrastructure Management (Terraform)

All infrastructure is provisioned and managed directly using Terraform CLI:

```bash
cd terraform

# Initialize with S3 remote state
terraform init

# Review changes
terraform plan

# Apply changes
terraform apply
```

---

### 📦 Local Helm Deployment

Deploy Helm releases to AWS EKS from your local machine:

```bash
# Connect kubectl to EKS cluster
aws eks update-kubeconfig --region ap-south-1 --name pulsewatch-eks

# Deploy to Staging
./scripts/deploy.sh staging

# Deploy to Production
./scripts/deploy.sh production
```