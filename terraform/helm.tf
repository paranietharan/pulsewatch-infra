# ==============================================================================
# In-Cluster Helm Controllers & Addons
# Automatically installs AWS Load Balancer Controller
# ==============================================================================

# ------------------------------------------------------------------------------
# Service Account for AWS Load Balancer Controller (IRSA)
# ------------------------------------------------------------------------------
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

# ------------------------------------------------------------------------------
# Install AWS Load Balancer Controller Helm Chart
# ------------------------------------------------------------------------------
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }

  depends_on = [
    aws_eks_node_group.main,
    kubernetes_service_account.aws_load_balancer_controller
  ]
}

# ------------------------------------------------------------------------------
# Staging & Production Domain Locals
# ------------------------------------------------------------------------------
locals {
  staging_domain    = var.staging_domain_name != "" ? var.staging_domain_name : (var.domain_name != "" ? "staging.${var.domain_name}" : "")
  production_domain = var.production_domain_name != "" ? var.production_domain_name : var.domain_name
}

# ------------------------------------------------------------------------------
# PulseWatch Helm Release - Staging Environment (Namespace: staging)
# ------------------------------------------------------------------------------
resource "helm_release" "pulsewatch_staging" {
  count     = var.deploy_staging_helm ? 1 : 0
  name      = "pulsewatch-staging"
  chart     = "${path.module}/../helm/pulsewatch"
  namespace = var.staging_namespace

  values = [
    file("${path.module}/../helm/pulsewatch/values.yaml"),
    file("${path.module}/../helm/pulsewatch/values-staging.yaml"),
    yamlencode({
      database = {
        host     = var.enable_rds ? aws_db_instance.postgres[0].address : "pulsewatch-postgresql"
        port     = 5432
        dbName   = var.staging_db_name
        user     = var.db_username
        password = local.db_password
        sslmode  = var.enable_rds ? "require" : "disable"
      }
      ingress = {
        enabled = local.staging_domain != ""
        annotations = merge(
          {
            "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
            "alb.ingress.kubernetes.io/target-type" = "ip"
            "alb.ingress.kubernetes.io/group.name"  = "pulsewatch-staging-alb"
            "alb.ingress.kubernetes.io/listen-ports" = jsonencode(
              var.acm_certificate_arn != "" ? [{ "HTTP" = 80 }, { "HTTPS" = 443 }] : [{ "HTTP" = 80 }]
            )
          },
          var.acm_certificate_arn != "" ? { "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn } : {}
        )
        hosts = local.staging_domain != "" ? [
          {
            host = local.staging_domain
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                service  = "web"
                port     = 80
              }
            ]
          },
          {
            host = "api.${local.staging_domain}"
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                service  = "api"
                port     = 8080
              }
            ]
          }
        ] : []
      }
    })
  ]

  depends_on = [
    aws_eks_node_group.main,
    kubernetes_namespace.staging,
    helm_release.aws_load_balancer_controller,
    aws_db_instance.postgres
  ]
}

# ------------------------------------------------------------------------------
# PulseWatch Helm Release - Production Environment (Namespace: production)
# ------------------------------------------------------------------------------
resource "helm_release" "pulsewatch_production" {
  count     = var.deploy_production_helm ? 1 : 0
  name      = "pulsewatch-production"
  chart     = "${path.module}/../helm/pulsewatch"
  namespace = var.production_namespace

  values = [
    file("${path.module}/../helm/pulsewatch/values.yaml"),
    file("${path.module}/../helm/pulsewatch/values-prod.yaml"),
    yamlencode({
      database = {
        host     = var.enable_rds ? aws_db_instance.postgres[0].address : "pulsewatch-postgresql"
        port     = 5432
        dbName   = var.db_name
        user     = var.db_username
        password = local.db_password
        sslmode  = var.enable_rds ? "require" : "disable"
      }
      ingress = {
        enabled = local.production_domain != ""
        annotations = merge(
          {
            "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
            "alb.ingress.kubernetes.io/target-type" = "ip"
            "alb.ingress.kubernetes.io/group.name"  = "pulsewatch-production-alb"
            "alb.ingress.kubernetes.io/listen-ports" = jsonencode(
              var.acm_certificate_arn != "" ? [{ "HTTP" = 80 }, { "HTTPS" = 443 }] : [{ "HTTP" = 80 }]
            )
          },
          var.acm_certificate_arn != "" ? { "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn } : {}
        )
        hosts = local.production_domain != "" ? [
          {
            host = local.production_domain
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                service  = "web"
                port     = 80
              }
            ]
          },
          {
            host = "api.${local.production_domain}"
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                service  = "api"
                port     = 8080
              }
            ]
          }
        ] : []
      }
    })
  ]

  depends_on = [
    aws_eks_node_group.main,
    kubernetes_namespace.production,
    helm_release.aws_load_balancer_controller,
    aws_db_instance.postgres
  ]
}
