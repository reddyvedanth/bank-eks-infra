# Backend config is supplied at init time (CI or local):
#   terraform init -backend-config=backend.hcl
terraform {
  backend "s3" {}
}
