#!/usr/bin/env bash
# AWS requires trust policies to scope token.actions.githubusercontent.com:sub
# OR job_workflow_ref (repository alone is rejected).
# GitHub sub uses numeric IDs: repo:owner@26704129/repo@1319174583:pull_request
set -euo pipefail

ROLE_NAME="bank-eks-github-actions"
OIDC_ARN="arn:aws:iam::202264954476:oidc-provider/token.actions.githubusercontent.com"

# Owner + repo IDs from GitHub API (stable for OIDC sub claim)
OWNER_ID="26704129"
INFRA_REPO_ID="1319174583"
APP_REPO_ID="1319174961"

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
          "repo:reddyvedanth@${OWNER_ID}/bank-eks-infra@${INFRA_REPO_ID}:*",
          "repo:reddyvedanth@${OWNER_ID}/bank-eks-app@${APP_REPO_ID}:*"
        ],
        "token.actions.githubusercontent.com:job_workflow_ref": [
          "reddyvedanth/bank-eks-infra/.github/workflows/*",
          "reddyvedanth/bank-eks-app/.github/workflows/*"
        ]
      }
    }
  }]
}
EOF
)"

echo "Updated trust policy on $ROLE_NAME"
aws iam get-role --role-name "$ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json
