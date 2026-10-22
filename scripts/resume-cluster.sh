#!/usr/bin/env bash
# ==============================================================================
# PulseWatch - Resume Infrastructure
# Starts RDS database, scales EKS worker nodes back to 2, and waits for pods.
# ==============================================================================

set -euo pipefail

REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${EKS_CLUSTER_NAME:-pulsewatch-eks}"
NODEGROUP_NAME="${EKS_NODEGROUP_NAME:-pulsewatch-eks-nodegroup}"
RDS_IDENTIFIER="${RDS_IDENTIFIER:-pulsewatch-eks-postgres}"

echo "=================================================================="
echo "      PulseWatch - Resuming Cluster & Workloads"
echo "=================================================================="
echo "Region:         $REGION"
echo "EKS Cluster:    $CLUSTER_NAME"
echo "Nodegroup:      $NODEGROUP_NAME"
echo "RDS Instance:   $RDS_IDENTIFIER"
echo "=================================================================="

# 1. Start RDS Instance
echo "==> [1/3] Checking Amazon RDS PostgreSQL status..."
RDS_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS_IDENTIFIER" \
  --region "$REGION" \
  --query "DBInstances[0].DBInstanceStatus" \
  --output text 2>/dev/null || echo "not_found")

if [ "$RDS_STATUS" = "stopped" ]; then
  echo "    Starting RDS instance '$RDS_IDENTIFIER'..."
  aws rds start-db-instance \
    --db-instance-identifier "$RDS_IDENTIFIER" \
    --region "$REGION" >/dev/null
  echo "    ✓ RDS start request submitted. Instance will become available shortly."
elif [ "$RDS_STATUS" = "available" ] || [ "$RDS_STATUS" = "starting" ]; then
  echo "    ℹ RDS instance is already in '$RDS_STATUS' state."
else
  echo "    ⚠ RDS instance status is '$RDS_STATUS'."
fi

# 2. Scale EKS Node Group back to desired: 2, min: 2, max: 6
echo ""
echo "==> [2/3] Scaling EKS Managed Node Group back to 2 nodes..."
aws eks update-nodegroup-config \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --scaling-config minSize=2,desiredSize=2,maxSize=6 \
  --region "$REGION" >/dev/null

echo "    ✓ EKS Nodegroup '$NODEGROUP_NAME' scaling request sent (desired: 2, min: 2, max: 6)."
echo "    EC2 worker instances are booting up..."

# 3. Update kubeconfig and check node readiness
echo ""
echo "==> [3/3] Updating local kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" >/dev/null

echo "    Waiting for EC2 worker nodes to join cluster and become Ready..."
if kubectl wait --for=condition=Ready nodes --all --timeout=180s 2>/dev/null; then
  echo "    ✓ EC2 worker nodes are Ready!"
else
  echo "    ℹ Nodes are still booting. They will become Ready automatically within 1-2 minutes."
fi

echo ""
echo "=================================================================="
echo "  PulseWatch is resuming!"
echo "  Check pod status with: kubectl get pods -A"
echo "=================================================================="
