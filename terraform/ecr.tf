# ==============================================================================
# AWS Elastic Container Registry (ECR) Repositories
# ==============================================================================

locals {
  services = [
    "pulsewatch-api",
    "pulsewatch-web",
    "pulsewatch-scheduler",
    "pulsewatch-probe-worker",
    "pulsewatch-notification-service",
    "pulsewatch-db-migrator"
  ]
}

resource "aws_ecr_repository" "repos" {
  for_each             = var.enable_ecr ? toset(local.services) : toset([])
  name                 = each.key
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Service = each.key
  }
}

resource "aws_ecr_lifecycle_policy" "repos" {
  for_each   = var.enable_ecr ? toset(local.services) : toset([])
  repository = aws_ecr_repository.repos[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 images per service"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
