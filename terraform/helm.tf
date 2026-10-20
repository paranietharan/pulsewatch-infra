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
    value = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
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
# Optional: Deploy PulseWatch Application Helm Chart directly via Terraform
# ------------------------------------------------------------------------------
resource "helm_release" "pulsewatch" {
  count     = var.deploy_pulsewatch_helm ? 1 : 0
  name      = "pulsewatch"
  chart     = "${path.module}/../helm/pulsewatch"
  namespace = "pulsewatch"
  create_namespace = true

  values = [
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
        enabled = true
        annotations = {
          "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
          "alb.ingress.kubernetes.io/target-type" = "ip"
          "alb.ingress.kubernetes.io/listen-ports" = jsonencode([
            {"HTTP" = 80},
            {"HTTPS" = 443}
          ])
          "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn
        }
        hosts = [
          {
            host = var.domain_name
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                service  = "web"
              }
            ]
          },
          {
            host = "api.${var.domain_name}"
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                service  = "api"
              }
            ]
          }
        ]
      }
    })
  ]

  depends_on = [
    aws_eks_node_group.main,
    helm_release.aws_load_balancer_controller,
    aws_db_instance.postgres
  ]
}
