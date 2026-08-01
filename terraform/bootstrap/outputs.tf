output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.locks.name
}

output "state_key" {
  value = var.terraform_state_key
}

output "github_actions_role_arn" {
  description = "Set as GitHub repo variable AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "backend_hcl" {
  description = "Copy to terraform/backend.hcl"
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.state.bucket}"
    key            = "${var.terraform_state_key}"
    region         = "${var.aws_region}"
    dynamodb_table = "${aws_dynamodb_table.locks.name}"
    encrypt        = true
  EOT
}

output "github_variables" {
  description = "Set these in GitHub → Settings → Secrets and variables → Actions"
  value = {
    AWS_REGION           = var.aws_region
    TF_STATE_BUCKET      = aws_s3_bucket.state.bucket
    TF_STATE_KEY         = var.terraform_state_key
    TF_STATE_LOCK_TABLE  = aws_dynamodb_table.locks.name
    AWS_ROLE_ARN         = aws_iam_role.github_actions.arn
  }
}
