#!/usr/bin/env bash
# ==============================================================================
# PulseWatch - Pause / Hibernate Infrastructure
# Safely stops RDS database and scales EKS EC2 worker nodes to 0.
# Zero data loss. Cuts EC2 compute & RDS compute costs to $0 immediately.
# ==============================================================================

set -euo pipefail

REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${EKS_CLUSTER_NAME:-pulsewatch-eks}"
NODEGROUP_NAME="${EKS_NODEGROUP_NAME:-pulsewatch-eks-nodegroup}"
RDS_IDENTIFIER="${RDS_IDENTIFIER:-pulsewatch-eks-postgres}"

echo "=================================================================="
echo "      PulseWatch - Pausing Cluster & Workloads"
echo "=================================================================="
echo "Region:         $REGION"
echo "EKS Cluster:    $CLUSTER_NAME"
echo "Nodegroup:      $NODEGROUP_NAME"
echo "RDS Instance:   $RDS_IDENTIFIER"
echo "=================================================================="

# 1. Stop RDS Instance
echo "==> [1/2] Checking Amazon RDS PostgreSQL status..."
RDS_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier "$RDS_IDENTIFIER" \
  --region "$REGION" \
  --query "DBInstances[0].DBInstanceStatus" \
  --output text 2>/dev/null || echo "not_found")

if [ "$RDS_STATUS" = "available" ]; then
  echo "    Stopping RDS instance '$RDS_IDENTIFIER'..."
  aws rds stop-db-instance \
    --db-instance-identifier "$RDS_IDENTIFIER" \
    --region "$REGION" >/dev/null
  echo "    ✓ RDS instance stop request submitted successfully (Compute cost -> \$0)."
elif [ "$RDS_STATUS" = "stopped" ] || [ "$RDS_STATUS" = "stopping" ]; then
  echo "    ℹ RDS instance is already in '$RDS_STATUS' state."
else
  echo "    ⚠ RDS instance status is '$RDS_STATUS'. Skipping stop request."
fi

# 2. Scale EKS Node Group to 0
echo ""
echo "==> [2/2] Scaling EKS Managed Node Group to 0 nodes..."
aws eks update-nodegroup-config \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --scaling-config minSize=0,desiredSize=0,maxSize=0 \
  --region "$REGION" >/dev/null

echo "    ✓ EKS Nodegroup '$NODEGROUP_NAME' scaling request sent (desired: 0, min: 0, max: 0)."
echo "    AWS will terminate existing EC2 worker instances over the next 2-3 minutes."
echo ""
echo "=================================================================="
echo "  PulseWatch is now paused! All data in RDS & EBS is preserved."
echo "  To restore everything, run: ./scripts/resume-cluster.sh"
echo "=================================================================="
