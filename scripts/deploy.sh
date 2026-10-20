#!/usr/bin/env bash
# ==============================================================================
# Deploy / Upgrade PulseWatch Helm Release on AWS EKS
# Supports Staging and Production Namespaces
# Usage:
#   ./scripts/deploy.sh staging [image_tag] [ecr_registry]
#   ./scripts/deploy.sh production [image_tag] [ecr_registry]
# ==============================================================================

set -euo pipefail

ENV_TARGET="${1:-staging}"
IMAGE_TAG="${2:-${IMAGE_TAG:-latest}}"
ECR_REGISTRY="${3:-${ECR_REGISTRY:-}}"

CHART_PATH="helm/pulsewatch"

case "$ENV_TARGET" in
  staging|stage)
    NAMESPACE="staging"
    RELEASE_NAME="pulsewatch-staging"
    ENV_VALUES="helm/pulsewatch/values-staging.yaml"
    ;;
  production|prod)
    NAMESPACE="production"
    RELEASE_NAME="pulsewatch-production"
    ENV_VALUES="helm/pulsewatch/values-prod.yaml"
    ;;
  *)
    echo "Usage: $0 [staging|production] [optional:image_tag] [optional:ecr_registry]"
    echo ""
    echo "Examples:"
    echo "  $0 staging"
    echo "  $0 staging v1.2.0 123456789012.dkr.ecr.ap-south-1.amazonaws.com"
    echo "  $0 production"
    echo "  $0 production sha-abc1234"
    exit 1
    ;;
esac

echo "====================================================================="
echo "Deploying PulseWatch to AWS EKS"
echo "Target Environment: $ENV_TARGET"
echo "Release Name:       $RELEASE_NAME"
echo "Namespace:          $NAMESPACE"
echo "Base Values:        helm/pulsewatch/values.yaml"
echo "Env Values:         $ENV_VALUES"
echo "Image Tag:          $IMAGE_TAG"
if [ -n "$ECR_REGISTRY" ]; then
  echo "ECR Registry:       $ECR_REGISTRY"
fi
echo "====================================================================="

# Ensure namespace exists with proper environment label
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "$NAMESPACE" environment="$NAMESPACE" --overwrite || true

HELM_ARGS=(
  upgrade --install "$RELEASE_NAME" "$CHART_PATH"
  --namespace "$NAMESPACE"
  -f "helm/pulsewatch/values.yaml"
  -f "$ENV_VALUES"
  --wait
  --timeout 10m
)

# If custom image tag or ECR registry is specified, inject into Helm
if [ -n "$IMAGE_TAG" ] && [ "$IMAGE_TAG" != "latest" ]; then
  HELM_ARGS+=(
    --set api.image.tag="$IMAGE_TAG"
    --set web.image.tag="$IMAGE_TAG"
    --set scheduler.image.tag="$IMAGE_TAG"
    --set probeWorker.image.tag="$IMAGE_TAG"
    --set notificationService.image.tag="$IMAGE_TAG"
    --set migrator.image.tag="$IMAGE_TAG"
  )
fi

if [ -n "$ECR_REGISTRY" ]; then
  HELM_ARGS+=(
    --set api.image.repository="${ECR_REGISTRY}/pulsewatch-api"
    --set web.image.repository="${ECR_REGISTRY}/pulsewatch-web"
    --set scheduler.image.repository="${ECR_REGISTRY}/pulsewatch-scheduler"
    --set probeWorker.image.repository="${ECR_REGISTRY}/pulsewatch-probe-worker"
    --set notificationService.image.repository="${ECR_REGISTRY}/pulsewatch-notification-service"
    --set migrator.image.repository="${ECR_REGISTRY}/pulsewatch-db-migrator"
  )
fi

echo "--> Executing Helm rollout..."
helm "${HELM_ARGS[@]}"

echo ""
echo "====================================================================="
echo "Deployment completed successfully in namespace '${NAMESPACE}'!"
echo "====================================================================="
echo ""
echo "Pod status:"
kubectl get pods -n "$NAMESPACE" -o wide

echo ""
echo "Services:"
kubectl get svc -n "$NAMESPACE"

echo ""
echo "Ingress:"
kubectl get ingress -n "$NAMESPACE"
