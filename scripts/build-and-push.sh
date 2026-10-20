#!/usr/bin/env bash
# ==============================================================================
# Build & Push PulseWatch Container Images to AWS ECR
# Usage:
#   ./scripts/build-and-push.sh [image_tag] [aws_region] [source_dir]
# Examples:
#   ./scripts/build-and-push.sh latest
#   ./scripts/build-and-push.sh v1.0.0 us-east-1 ../pulsewatch
# ==============================================================================

set -euo pipefail

# Configuration Parameters (CLI arguments take precedence over environment variables)
IMAGE_TAG="${1:-${IMAGE_TAG:-latest}}"
AWS_REGION="${2:-${AWS_REGION:-us-east-1}}"
SOURCE_DIR="${3:-${SOURCE_DIR:-../pulsewatch}}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")}"

if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "ERROR: Could not resolve AWS_ACCOUNT_ID. Please export AWS_ACCOUNT_ID or configure AWS CLI."
  exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "====================================================================="
echo "Building and Pushing PulseWatch Images"
echo "AWS Region:   $AWS_REGION"
echo "AWS Account:  $AWS_ACCOUNT_ID"
echo "Registry:     $ECR_REGISTRY"
echo "Tag:          $IMAGE_TAG"
echo "Source Dir:   $SOURCE_DIR"
echo "====================================================================="

# Authenticate Docker with AWS ECR
echo "--> Logging into Amazon ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# Define microservices to build: "service_name:build_context:dockerfile_path"
SERVICES=(
  "pulsewatch-api:${SOURCE_DIR}/pulsewatch-api:${SOURCE_DIR}/pulsewatch-api/Dockerfile"
  "pulsewatch-web:${SOURCE_DIR}/pulse-watch-web:${SOURCE_DIR}/pulse-watch-web/Dockerfile"
  "pulsewatch-scheduler:${SOURCE_DIR}/pulsewatch-scheduler:${SOURCE_DIR}/pulsewatch-scheduler/Dockerfile"
  "pulsewatch-probe-worker:${SOURCE_DIR}/pulsewatch-probe-worker:${SOURCE_DIR}/pulsewatch-probe-worker/Dockerfile"
  "pulsewatch-notification-service:${SOURCE_DIR}/pulsewatch-notification-service:${SOURCE_DIR}/pulsewatch-notification-service/Dockerfile"
  "pulsewatch-db-migrator:${SOURCE_DIR}/pulse-watch-db:${SOURCE_DIR}/pulse-watch-db/Dockerfile"
)

for item in "${SERVICES[@]}"; do
  IFS=":" read -r SVC_NAME SVC_CONTEXT SVC_DOCKERFILE <<< "$item"
  REMOTE_IMAGE="${ECR_REGISTRY}/${SVC_NAME}:${IMAGE_TAG}"

  echo ""
  echo "---------------------------------------------------------------------"
  echo "Building: ${SVC_NAME}"
  echo "Context:  ${SVC_CONTEXT}"
  echo "Remote:   ${REMOTE_IMAGE}"
  echo "---------------------------------------------------------------------"

  BUILD_TAGS=("-t" "$REMOTE_IMAGE")
  if [ "$IMAGE_TAG" != "latest" ]; then
    BUILD_TAGS+=("-t" "${ECR_REGISTRY}/${SVC_NAME}:latest")
  fi

  docker build \
    --platform linux/amd64 \
    -f "$SVC_DOCKERFILE" \
    "${BUILD_TAGS[@]}" \
    "$SVC_CONTEXT"

  echo "--> Pushing ${REMOTE_IMAGE}..."
  docker push "$REMOTE_IMAGE"

  if [ "$IMAGE_TAG" != "latest" ]; then
    echo "--> Pushing ${ECR_REGISTRY}/${SVC_NAME}:latest..."
    docker push "${ECR_REGISTRY}/${SVC_NAME}:latest"
  fi
done

echo ""
echo "====================================================================="
echo "All PulseWatch container images built and pushed successfully to ECR!"
echo "====================================================================="
