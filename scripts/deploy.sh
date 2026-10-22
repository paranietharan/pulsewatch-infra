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
    ENV_SHORT="staging"
    RELEASE_NAME="pulsewatch-staging"
    ENV_VALUES="helm/pulsewatch/values-staging.yaml"
    ;;
  production|prod)
    NAMESPACE="production"
    ENV_SHORT="prod"
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

# Auto-discover DB password if not provided
DB_PASS="${DB_PASSWORD:-}"
if [ -z "$DB_PASS" ]; then
  DB_SECRET_RAW=$(aws secretsmanager get-secret-value --secret-id "pulsewatch-eks-rds-credentials" --region ap-south-1 --query "SecretString" --output text 2>/dev/null || echo "")
  if [ -n "$DB_SECRET_RAW" ] && [ "$DB_SECRET_RAW" != "None" ]; then
    DB_PASS=$(echo "$DB_SECRET_RAW" | jq -r '.password // empty')
  fi
fi

HELM_ARGS=(
  upgrade --install "$RELEASE_NAME" "$CHART_PATH"
  --namespace "$NAMESPACE"
  -f "helm/pulsewatch/values.yaml"
  -f "$ENV_VALUES"
  --wait
  --timeout 10m
)

if [ -n "$DB_PASS" ]; then
  HELM_ARGS+=(--set "database.password=${DB_PASS}")
fi

# Auto-discover SMTP credentials from AWS Secrets Manager if available
SMTP_SECRET_RAW=$(aws secretsmanager get-secret-value --secret-id "pulsewatch-${ENV_SHORT}-smtp-credentials" --region ap-south-1 --query "SecretString" --output text 2>/dev/null || echo "")
if [ -n "$SMTP_SECRET_RAW" ] && [ "$SMTP_SECRET_RAW" != "None" ]; then
  RESOLVED_SMTP_USER=$(echo "$SMTP_SECRET_RAW" | jq -r '.user // empty')
  RESOLVED_SMTP_PASS=$(echo "$SMTP_SECRET_RAW" | jq -r '.password // empty')
  RESOLVED_SMTP_HOST=$(echo "$SMTP_SECRET_RAW" | jq -r '.host // empty')
  RESOLVED_SMTP_PORT=$(echo "$SMTP_SECRET_RAW" | jq -r '.port // empty')
  RESOLVED_SMTP_FROM=$(echo "$SMTP_SECRET_RAW" | jq -r '.from // empty')

  [ -n "$RESOLVED_SMTP_USER" ] && HELM_ARGS+=(--set "smtp.user=${RESOLVED_SMTP_USER}")
  [ -n "$RESOLVED_SMTP_PASS" ] && HELM_ARGS+=(--set "smtp.password=${RESOLVED_SMTP_PASS}")
  [ -n "$RESOLVED_SMTP_HOST" ] && HELM_ARGS+=(--set "smtp.host=${RESOLVED_SMTP_HOST}")
  [ -n "$RESOLVED_SMTP_PORT" ] && HELM_ARGS+=(--set "smtp.port=${RESOLVED_SMTP_PORT}")
  [ -n "$RESOLVED_SMTP_FROM" ] && HELM_ARGS+=(--set "smtp.from=${RESOLVED_SMTP_FROM}")
  echo "--> Injected SMTP credentials from AWS Secrets Manager (pulsewatch-${ENV_SHORT}-smtp-credentials)"
fi

# Auto-discover JWT secret from AWS Secrets Manager if available
JWT_SECRET_RAW=$(aws secretsmanager get-secret-value --secret-id "pulsewatch-${ENV_SHORT}-jwt-secret" --region ap-south-1 --query "SecretString" --output text 2>/dev/null || echo "")
if [ -n "$JWT_SECRET_RAW" ] && [ "$JWT_SECRET_RAW" != "None" ]; then
  RESOLVED_JWT_SECRET=$(echo "$JWT_SECRET_RAW" | jq -r '.jwt_secret // .secret // empty' 2>/dev/null || echo "")
  if [ -z "$RESOLVED_JWT_SECRET" ]; then
    RESOLVED_JWT_SECRET="$JWT_SECRET_RAW"
  fi
  HELM_ARGS+=(--set "api.jwtSecret=${RESOLVED_JWT_SECRET}")
  echo "--> Injected JWT secret from AWS Secrets Manager (pulsewatch-${ENV_SHORT}-jwt-secret)"
fi

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
