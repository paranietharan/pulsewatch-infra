# PulseWatch Infrastructure Guide

Quick guide to destroy the entire infrastructure to stop all AWS costs, and recreate it whenever needed.

---

## 🛑 How to Destroy Everything

### Step 1: Backup Database
Save an RDS snapshot so you do not lose any database data.
```bash
aws rds create-db-snapshot \
  --db-instance-identifier pulsewatch-eks-postgres \
  --db-snapshot-identifier "pulsewatch-backup-$(date +%Y%m%d)" \
  --region ap-south-1
```

### Step 2: Remove Workloads & Load Balancers
Uninstall Helm charts and delete storage volumes so AWS deletes the Application Load Balancers cleanly.
```bash
helm uninstall pulsewatch-production -n production 2>/dev/null || true
helm uninstall pulsewatch-staging -n staging 2>/dev/null || true
kubectl delete pvc --all -n production 2>/dev/null || true
kubectl delete pvc --all -n staging 2>/dev/null || true
sleep 45
```

### Step 3: Destroy AWS Resources
Run Terraform destroy to tear down the EKS cluster, RDS instance, and VPC.
```bash
cd terraform
terraform destroy -auto-approve
```

---

## ▶️ How to Recreate Everything

### Step 1: Provision Infrastructure
Recreate the VPC, EKS cluster, node groups, and RDS database.
```bash
cd terraform
terraform apply -auto-approve
```

### Step 2: Connect kubectl
Update your local Kubernetes configuration to connect to the new cluster.
```bash
aws eks update-kubeconfig --region ap-south-1 --name pulsewatch-eks
```

### Step 3: Deploy Applications
Roll out the microservices to staging and production namespaces.
```bash
cd ..
./scripts/deploy.sh staging
./scripts/deploy.sh production
```