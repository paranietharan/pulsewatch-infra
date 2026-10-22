# ==============================================================================
# AWS RDS PostgreSQL Instance (Production Database)
# ==============================================================================

resource "random_password" "db_password" {
  count   = var.enable_rds && var.db_password == "" ? 1 : 0
  length  = 24
  special = false
}

locals {
  db_password = var.db_password != "" ? var.db_password : (length(random_password.db_password) > 0 ? random_password.db_password[0].result : "")
}

# ------------------------------------------------------------------------------
# DB Subnet Group
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  count      = var.enable_rds ? 1 : 0
  name       = "${var.cluster_name}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name = "${var.cluster_name}-db-subnet-group"
  }
}

# ------------------------------------------------------------------------------
# RDS Security Group (Ingress restricted to EKS Worker Node Security Group)
# ------------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  count       = var.enable_rds ? 1 : 0
  name        = "${var.cluster_name}-rds-sg"
  description = "Controls traffic to PulseWatch RDS PostgreSQL instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL from EKS worker nodes, cluster, and VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [
      aws_security_group.node.id,
      aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
    ]
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-rds-sg"
  }
}

# ------------------------------------------------------------------------------
# DB Parameter Group
# ------------------------------------------------------------------------------
resource "aws_db_parameter_group" "pg16" {
  count  = var.enable_rds ? 1 : 0
  name   = "${var.cluster_name}-pg16-params"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = {
    Name = "${var.cluster_name}-pg16-params"
  }
}

# ------------------------------------------------------------------------------
# RDS PostgreSQL Instance
# ------------------------------------------------------------------------------
resource "aws_db_instance" "postgres" {
  count                  = var.enable_rds ? 1 : 0
  identifier             = "${var.cluster_name}-postgres"
  engine                 = "postgres"
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = var.db_max_allocated_storage
  storage_type           = "gp3"
  db_name                = var.db_name
  username               = var.db_username
  password               = local.db_password
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]
  parameter_group_name   = aws_db_parameter_group.pg16[0].name

  multi_az            = var.db_multi_az
  publicly_accessible = false
  skip_final_snapshot = true
  deletion_protection = false

  backup_retention_period = var.db_backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:04:30-Sun:05:30"

  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.cluster_name}-postgres"
  }
}

# ------------------------------------------------------------------------------
# Store RDS Master Credentials in AWS Secrets Manager
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "rds_credentials" {
  count                   = var.enable_rds ? 1 : 0
  name                    = "${var.cluster_name}-rds-credentials"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.cluster_name}-rds-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  count     = var.enable_rds ? 1 : 0
  secret_id = aws_secretsmanager_secret.rds_credentials[0].id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.postgres[0].address
    port     = aws_db_instance.postgres[0].port
    database = aws_db_instance.postgres[0].db_name
    username = aws_db_instance.postgres[0].username
    password = local.db_password
  })
}


