# PulseWatch Infrastructure & AWS EKS Multi-Environment Deployment


### 🔐 Required GitHub Actions Secrets

To run automated CI/CD and deployment workflows in `pulsewatch-infra`, configure the following repository secrets under **Settings ➔ Secrets and variables ➔ Actions**:

| Secret Name | Required? | Example Value | Description |
|---|:---:|---|---|
| `AWS_ACCESS_KEY_ID` | **Yes** | `AKIAIOSFODNN7EXAMPLE` | AWS IAM Access Key ID for runner authentication. Must have permissions for EKS, ECR, RDS, VPC, and S3/DynamoDB state. |
| `AWS_SECRET_ACCESS_KEY` | **Yes** | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` | Corresponding AWS IAM Secret Access Key. |
| `TF_STATE_BUCKET` | *Optional* | `pulsewatch-tf-state-123456` | S3 bucket holding Terraform remote state. Output by `terraform/backend_setup`. (If omitted, the workflow attempts auto-discovery). |

> [!TIP]
> **Minimal IAM Policy Permissions Required:**
> - `AmazonEKSClusterPolicy` / `AmazonEKSWorkerNodePolicy`
> - `AmazonEC2ContainerRegistryPowerUser`
> - `AmazonRDSFullAccess`
> - `AmazonVPCFullAccess`
> - S3 & DynamoDB read/write access to the state bucket and locking table (`pulsewatch-terraform-locks`).