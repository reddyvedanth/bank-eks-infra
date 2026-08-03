#!/usr/bin/env bash
# Run once locally if Plan/Apply OIDC fails with AssumeRoleWithWebIdentity.
# Widens trust on bank-eks-github-actions to accept any sub from your two repos.
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
        "token.actions.githubusercontent.com:sub": [
          "repo:reddyvedanth/bank-eks-infra:*",
          "repo:reddyvedanth/bank-eks-app:*"
        ]
      }
    }
  }]
}
EOF
)"

echo "Updated trust policy on $ROLE_NAME"
aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument.Statement[0].Condition' --output json
