# -----------------------------------------------------------------------------
# RDS PostgreSQL — private subnets only, reachable from EKS nodes via SG
# -----------------------------------------------------------------------------

module "rds_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-rds"
  description = "PostgreSQL from EKS worker nodes only"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "postgresql-tcp"
      source_security_group_id = module.eks.node_security_group_id
    },
  ]

  egress_rules = ["all-all"]

  tags = local.common_tags
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${local.name}-postgres"

  engine               = "postgres"
  engine_version       = "16"
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = "db.t3.micro"

  allocated_storage = 20
  storage_encrypted = true

  db_name  = "appdb"
  username = var.db_username
  password = var.db_password

  multi_az               = var.environment == "prod"
  vpc_security_group_ids = [module.rds_sg.security_group_id]

  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets

  backup_retention_period = var.environment == "prod" ? 7 : 1
  deletion_protection     = var.environment == "prod"
  skip_final_snapshot     = var.environment != "prod"

  tags = local.common_tags
}
