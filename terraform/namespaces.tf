# ==============================================================================
# Kubernetes Namespaces for Multi-Environment Deployment
# Provisions isolated namespaces for Staging and Production workloads
# ==============================================================================

# ------------------------------------------------------------------------------
# Staging Namespace
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "staging" {
  metadata {
    name = var.staging_namespace
    labels = {
      name                           = var.staging_namespace
      environment                    = "staging"
      "app.kubernetes.io/part-of"    = "pulsewatch"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_node_group.main, aws_eks_access_policy_association.admins]
}

# ------------------------------------------------------------------------------
# Production Namespace
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "production" {
  metadata {
    name = var.production_namespace
    labels = {
      name                           = var.production_namespace
      environment                    = "production"
      "app.kubernetes.io/part-of"    = "pulsewatch"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_node_group.main, aws_eks_access_policy_association.admins]
}

# ------------------------------------------------------------------------------
# Staging Resource Quotas (Prevents Staging from Starving Production)
# ------------------------------------------------------------------------------
resource "kubernetes_resource_quota" "staging" {
  count = var.enable_namespace_quotas ? 1 : 0

  metadata {
    name      = "${var.staging_namespace}-quota"
    namespace = kubernetes_namespace.staging.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "4"
      "requests.memory" = "8Gi"
      "limits.cpu"      = "8"
      "limits.memory"   = "16Gi"
      "pods"            = "30"
    }
  }
}

# ------------------------------------------------------------------------------
# Production Resource Quotas
# ------------------------------------------------------------------------------
resource "kubernetes_resource_quota" "production" {
  count = var.enable_namespace_quotas ? 1 : 0

  metadata {
    name      = "${var.production_namespace}-quota"
    namespace = kubernetes_namespace.production.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "16"
      "requests.memory" = "32Gi"
      "limits.cpu"      = "32"
      "limits.memory"   = "64Gi"
      "pods"            = "100"
    }
  }
}
