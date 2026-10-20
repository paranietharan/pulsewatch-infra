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
  for_each             = var.enable_ecr ? toset(locals.services) : []
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
  for_each   = var.enable_ecr ? toset(locals.services) : []
  repository = aws_ecr_repository.repos[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 30 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest", "sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
