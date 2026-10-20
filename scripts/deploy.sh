#!/usr/bin/env bash
# ==============================================================================
# Deploy / Upgrade PulseWatch Helm Release on AWS EKS
# ==============================================================================

set -euo pipefail

NAMESPACE="${NAMESPACE:-pulsewatch}"
RELEASE_NAME="${RELEASE_NAME:-pulsewatch}"
CHART_PATH="${CHART_PATH:-helm/pulsewatch}"
VALUES_FILE="${VALUES_FILE:-helm/pulsewatch/values.yaml}"

echo "====================================================================="
echo "Deploying PulseWatch to AWS EKS"
echo "Release Name: $RELEASE_NAME"
echo "Namespace:    $NAMESPACE"
echo "Values:       $VALUES_FILE"
echo "====================================================================="

# Ensure namespace exists
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Deploy Helm Chart
helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
  --namespace "$NAMESPACE" \
  -f "$VALUES_FILE" \
  --wait \
  --timeout 10m

echo ""
echo "Deployment completed. Checking pods in namespace '${NAMESPACE}':"
kubectl get pods -n "$NAMESPACE" -o wide

echo ""
echo "Ingress details:"
kubectl get ingress -n "$NAMESPACE"
