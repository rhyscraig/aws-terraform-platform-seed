# craighoad.com Account Setup Guide

## Overview

The `website-static-html-craighoad.com` repository needs to deploy infrastructure to the craighoad.com production account (767828739298). This guide covers setting up the OIDC provider and IAM role in that account to enable terraform deployments via GitHub Actions.

## Architecture

```
GitHub Actions (website-static-html-craighoad.com repo)
    ↓ (OIDC token)
OIDC Provider (craighoad.com account)
    ↓ (assume role)
craighoad-prod-oidc-role
    ↓ (write state)
hcp-cmc-euw1-platform-tfstate-prd (management account)
    ↓ (deploy infrastructure)
S3 + CloudFront + Route53 (craighoad.com account)
```

## Prerequisites

- AWS CLI configured with access to craighoad.com production account (767828739298)
- GitHub token available for repository setup
- Repository: `rhyscraig/website-static-html-craighoad.com`

## Step 1: Create OIDC Provider (One-Time)

If the GitHub OIDC provider doesn't already exist in the craighoad.com account, create it:

```bash
AWS_ACCOUNT=767828739298
AWS_REGION=eu-west-1

# Set your AWS credentials for the craighoad.com account
export AWS_PROFILE=terrorgem-prod  # or your craighoad profile

OIDC_URL="https://token.actions.githubusercontent.com"
OIDC_HOST="token.actions.githubusercontent.com"
THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"

# Check if provider already exists
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn "arn:aws:iam::${AWS_ACCOUNT}:oidc-provider/${OIDC_HOST}" \
  || {
  echo "Creating OIDC provider..."
  aws iam create-open-id-connect-provider \
    --url "$OIDC_URL" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "$THUMBPRINT"
}
```

## Step 2: Create OIDC IAM Role

Create the OIDC role that GitHub Actions will assume:

```bash
# Create trust policy document
cat > /tmp/craighoad-oidc-trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::767828739298:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:rhyscraig/website-static-html-craighoad.com:ref:refs/heads/main",
            "repo:rhyscraig/website-static-html-craighoad.com:environment:myorg"
          ]
        }
      }
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name craighoad-prod-oidc-role \
  --assume-role-policy-document file:///tmp/craighoad-oidc-trust-policy.json \
  --description "OIDC role for GitHub Actions deployments from website-static-html-craighoad.com" \
  || echo "Role already exists"

# Capture the ARN for later use
ROLE_ARN=$(aws iam get-role --role-name craighoad-prod-oidc-role --query 'Role.Arn' --output text)
echo "OIDC Role ARN: $ROLE_ARN"
```

## Step 3: Create IAM Policy for State Bucket Access

```bash
# Create cross-account state bucket access policy
cat > /tmp/craighoad-state-access-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3StateAccess",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::hcp-cmc-euw1-platform-tfstate-prd",
        "arn:aws:s3:::hcp-cmc-euw1-platform-tfstate-prd/hcp/prd/craighoad-website/*"
      ]
    },
    {
      "Sid": "KMSAccess",
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ],
      "Resource": "arn:aws:kms:eu-west-1:395101865577:key/62386c0f-c887-4be5-915e-c6167f2b56d1"
    }
  ]
}
EOF

# Create the policy
POLICY_ARN=$(aws iam create-policy \
  --policy-name craighoad-prod-state-access \
  --policy-document file:///tmp/craighoad-state-access-policy.json \
  --query 'Policy.Arn' \
  --output text)

echo "Policy ARN: $POLICY_ARN"

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name craighoad-prod-oidc-role \
  --policy-arn "$POLICY_ARN"
```

## Step 4: Create Website Deployment Policy

```bash
# Create policy for S3 + CloudFront + Route53 access (customize as needed)
cat > /tmp/craighoad-website-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3WebsiteAccess",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetBucketCors",
        "s3:PutBucketCors",
        "s3:GetBucketWebsite",
        "s3:PutBucketWebsite"
      ],
      "Resource": [
        "arn:aws:s3:::craighoad.com",
        "arn:aws:s3:::craighoad.com/*"
      ]
    },
    {
      "Sid": "CloudFrontAccess",
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateDistribution",
        "cloudfront:UpdateDistribution",
        "cloudfront:DeleteDistribution",
        "cloudfront:GetDistribution",
        "cloudfront:CreateInvalidation",
        "cloudfront:ListDistributions"
      ],
      "Resource": "arn:aws:cloudfront::767828739298:distribution/*"
    },
    {
      "Sid": "Route53Access",
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:GetHostedZone",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/*"
    },
    {
      "Sid": "IAMCertificateAccess",
      "Effect": "Allow",
      "Action": [
        "acm:RequestCertificate",
        "acm:DescribeCertificate",
        "acm:ListCertificates",
        "acm:DeleteCertificate"
      ],
      "Resource": "arn:aws:acm:*:767828739298:certificate/*"
    }
  ]
}
EOF

# Create and attach the policy
WEBSITE_POLICY_ARN=$(aws iam create-policy \
  --policy-name craighoad-prod-website-deploy \
  --policy-document file:///tmp/craighoad-website-policy.json \
  --query 'Policy.Arn' \
  --output text)

aws iam attach-role-policy \
  --role-name craighoad-prod-oidc-role \
  --policy-arn "$WEBSITE_POLICY_ARN"
```

## Step 5: Update Seed Terraform

Add the craighoad OIDC role ARN to the seed repo's myorg.tfvars:

```bash
CRAIGHOAD_ROLE_ARN="arn:aws:iam::767828739298:role/craighoad-prod-oidc-role"
```

Then update `/Users/craighoad/Repos/seed/configs/orgs/myorg.tfvars`:

```hcl
craighoad_oidc_role_arn = "arn:aws:iam::767828739298:role/craighoad-prod-oidc-role"
```

Re-run terraform in the seed repo to apply the cross-account bucket policy:

```bash
cd /Users/craighoad/Repos/seed/seed-terraform
terraform apply -var-file="../configs/orgs/myorg.tfvars"
```

## Step 6: Configure GitHub Secrets

In the `website-static-html-craighoad.com` repository, create a GitHub environment `myorg` with secrets:

```bash
gh secret set TF_STATE_BUCKET -b "hcp-cmc-euw1-platform-tfstate-prd" -e myorg
gh secret set KMS_KEY_ID -b "alias/hcp-cmc-euw1-platform-tfstate" -e myorg
gh secret set AWS_REGION -b "eu-west-1" -e myorg
gh secret set CRAIGHOAD_AWS_ROLE_TO_ASSUME -b "arn:aws:iam::767828739298:role/craighoad-prod-oidc-role" -e myorg
```

## Step 7: GitHub Actions Workflow Setup

In the website repository, create a `.github/workflows/terraform-deploy.yml`:

```yaml
name: Terraform Deploy

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'

permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest
    environment: myorg
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.CRAIGHOAD_AWS_ROLE_TO_ASSUME }}
          aws-region: ${{ secrets.AWS_REGION }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.14.5
      
      - name: Terraform Init
        run: |
          terraform -chdir=terraform init \
            -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" \
            -backend-config="key=hcp/prd/craighoad-website/craighoad/eu-west-1/terraform.tfstate" \
            -backend-config="region=${{ secrets.AWS_REGION }}" \
            -backend-config="encrypt=true" \
            -backend-config="use_lockfile=true"
      
      - name: Terraform Plan
        run: terraform -chdir=terraform plan -var-file="../configs/orgs/myorg.tfvars"
      
      - name: Terraform Apply
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: terraform -chdir=terraform apply -auto-approve -var-file="../configs/orgs/myorg.tfvars"
```

## Step 8: Create Terraform Code for Website

The website repository needs terraform code to deploy the infrastructure. Create `terraform/` directory with:

- `main.tf` - S3 bucket, CloudFront distribution, Route53 records
- `variables.tf` - Input variables (domain, ACM certificate, etc.)
- `outputs.tf` - CloudFront URL, hosted zone name servers
- `backend.tf` - Already created (backend.tf in root of repo)

## Verification

1. **Verify OIDC Provider:**
   ```bash
   aws iam list-open-id-connect-providers
   ```

2. **Verify OIDC Role:**
   ```bash
   aws iam get-role --role-name craighoad-prod-oidc-role
   aws iam list-attached-role-policies --role-name craighoad-prod-oidc-role
   ```

3. **Verify Cross-Account Bucket Policy:**
   ```bash
   # Switch to management account
   aws s3api get-bucket-policy --bucket hcp-cmc-euw1-platform-tfstate-prd
   ```

4. **Test GitHub Actions Workflow:**
   - Push a change to the website repository
   - Observe GitHub Actions workflow execution
   - Verify terraform plan succeeds

## Troubleshooting

### "AssumeRole" failure
- Verify OIDC subject conditions match the GitHub ref/environment
- Ensure GitHub token has correct permissions

### "Access Denied" on state bucket
- Verify S3 bucket policy includes craighoad OIDC role ARN
- Check KMS key permissions (key policy should allow the role)

### Terraform state file not found
- Verify `backend.tf` exists in the repository with correct bucket and key
- Ensure S3 path (`hcp/prd/craighoad-website/*`) exists or will be created automatically

## Next Steps

After successful OIDC setup:

1. Create terraform code for website infrastructure (S3, CloudFront, Route53)
2. Deploy website infrastructure via GitHub Actions workflow
3. Run `terraform destroy` workflow to decommission old infrastructure
4. Remove old state bucket and associated resources
