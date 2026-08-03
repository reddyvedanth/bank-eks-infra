#!/usr/bin/env bash
# GitHub OIDC sub now uses numeric IDs (repo:owner@123/repo@456:pull_request).
# Use the stable "repository" JWT claim instead — AWS recommended pattern.
set -euo pipefail

ROLE_NAME="bank-eks-github-actions"
OIDC_ARN="arn:aws:iam::202264954476:oidc-provider/token.actions.githubusercontent.com"

aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "$OIDC_ARN" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:repository": [
          "reddyvedanth/bank-eks-infra",
          "reddyvedanth/bank-eks-app"
        ]
      }
    }
  }]
}
EOF
)"

echo "Updated trust policy on $ROLE_NAME"
aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json
