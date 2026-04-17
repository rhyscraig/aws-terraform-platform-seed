# Centralized Terraform Backend Strategy

## Overview

All platform terraform repositories will use a centralized S3 bucket in the management account for state storage. This enables:
- Unified state management across 5+ repositories
- Parallel terraform execution across multiple repos
- Simplified state bucket management
- KMS encryption and versioning at a single location
- Cross-account writes for satellite accounts (e.g., craighoad.com)

## Architecture

### Central State Bucket
- **Bucket Name:** `hcp-cmc-euw1-platform-tfstate-prd`
- **Location:** Management account (`395101865577`)
- **Region:** `eu-west-1`
- **Encryption:** KMS (key: `alias/hcp-cmc-euw1-platform-tfstate`)
- **Versioning:** Enabled (retention: 90 days for non-current versions)
- **Locking:** S3 object locking via `use_lockfile = true` (no DynamoDB)

### S3 Path Structure

State files are organized hierarchically to support parallel builds and cross-org deployments:

```
hcp/prd/platform/aws-accounts/eu-west-1/terraform.tfstate
hcp/prd/platform/aws-baselines/eu-west-1/terraform.tfstate
hcp/prd/platform/aws-org/eu-west-1/terraform.tfstate
hcp/prd/terrorgems/terrorgem/eu-west-1/terraform.tfstate
hcp/prd/craighoad-website/craighoad/eu-west-1/terraform.tfstate
```

#### Path Components
- **org:** `hcp` - Organization identifier
- **environment:** `prd` - Deployment environment (prd, dev, staging, etc.)
- **system:** `platform|terrorgems|craighoad-website` - System/solution area
- **component:** Specific repository/component name
- **region:** AWS region where resources are deployed

#### Repositories → Paths

| Repository | System | Component | State Path | Deploys To |
|-----------|--------|-----------|-----------|-----------|
| aws-terraform-platform-aws-accounts | platform | aws-accounts | `hcp/prd/platform/aws-accounts/eu-west-1/terraform.tfstate` | All member accounts |
| aws-terraform-platform-aws-baselines | platform | aws-baselines | `hcp/prd/platform/aws-baselines/eu-west-1/terraform.tfstate` | All member accounts |
| aws-terraform-platform-aws-org | platform | aws-org | `hcp/prd/platform/aws-org/eu-west-1/terraform.tfstate` | Management account |
| aws-terraform-solutions-terrorgem | terrorgems | terrorgem | `hcp/prd/terrorgems/terrorgem/eu-west-1/terraform.tfstate` | Management account |
| website-static-html-craighoad.com | craighoad-website | craighoad | `hcp/prd/craighoad-website/craighoad/eu-west-1/terraform.tfstate` | craighoad.com prod account |
| seed-terraform | platform | seed | `hcp/prd/platform/seed/eu-west-1/terraform.tfstate` | Management account |

### Cross-Account State Access

#### Standard Repositories (Management Account)
- Run terraform from management account
- Use OIDC role in management account (already authenticated via GitHub Actions)
- Write directly to central bucket

#### Satellite Repositories (craighoad.com)
- Run terraform in craighoad.com production account
- OIDC role exists in craighoad.com account
- Required: S3 cross-account bucket policy allowing craighoad.com account to write to management bucket prefix

**Cross-Account Bucket Policy:**
```json
{
  "Sid": "AllowCraighoaMapProductionAccountStateWrite",
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::CRAIGHOAD_PROD_ACCOUNT:role/craighoad-prod-oidc-role"
  },
  "Action": [
    "s3:PutObject",
    "s3:GetObject",
    "s3:ListBucket"
  ],
  "Resource": [
    "arn:aws:s3:::hcp-cmc-euw1-platform-tfstate-prd/hcp/prd/craighoad-website/*",
    "arn:aws:s3:::hcp-cmc-euw1-platform-tfstate-prd"
  ]
}
```

## Backend Configuration

### Static Backend (Direct S3)

For repositories where the backend path is known and fixed:

```hcl
terraform {
  backend "s3" {
    bucket         = "hcp-cmc-euw1-platform-tfstate-prd"
    key            = "hcp/prd/platform/aws-org/eu-west-1/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "" # No DynamoDB locking
    use_lockfile   = true
  }
}
```

### Dynamic Backend (Variables)

For repositories where backend path varies, use `-backend-config` flags during init. This pattern allows a single repo to deploy to multiple target accounts:

```bash
terraform init \
  -backend-config="bucket=hcp-cmc-euw1-platform-tfstate-prd" \
  -backend-config="key=hcp/prd/platform/aws-accounts/eu-west-1/terraform.tfstate" \
  -backend-config="region=eu-west-1" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"
```

## Implementation Approach

### Phase 1: Core Backend Files
1. Create `configs/orgs/<org>.tfvars` in each repository with org-specific variables
2. Update `backend.tf` in each repository to point to new bucket and path
3. Update seed-terraform `github_oidc_subjects` to include all platform repos
4. Add cross-account S3 bucket policy for craighoad.com account

### Phase 2: State Migration
1. Migrate existing state from old bucket to new bucket/paths (using `terraform state pull/push`)
2. Verify all resources imported correctly
3. Commit and push terraform lock files

### Phase 3: GitHub Actions Workflow Updates
1. Update GitHub Actions workflows to use new backend configuration
2. Update GitHub environment secrets to reference new bucket and KMS key
3. Test parallel terraform execution across multiple repos

### Phase 4: Decommissioning
1. Run `terraform destroy` workflow for old craighoad.com infrastructure
2. Remove old state bucket and associated resources
3. Archive old bucket name in documentation

## Benefits

1. **Unified State Management:** Single bucket for all org infrastructure reduces bucket management overhead
2. **Scalability:** Path structure supports adding new systems, components, and regions without bucket changes
3. **Security:** Single KMS key manages encryption for all state; cross-account policy enforces least privilege
4. **Parallelism:** Separate state files enable simultaneous terraform runs across different repos
5. **Cost:** No DynamoDB table; S3 versioning provides state history; KMS costs amortized across all repos
6. **Auditability:** CloudTrail logs all bucket access; versioning preserves historical state

## AWS IAM Permissions Required

### OIDC Role (Management Account)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3StateAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::hcp-cmc-euw1-platform-tfstate-prd",
        "arn:aws:s3:::hcp-cmc-euw1-platform-tfstate-prd/*"
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
      "Resource": "arn:aws:kms:eu-west-1:395101865577:key/KEYID"
    }
  ]
}
```

### Cross-Account OIDC Role (craighoad.com Account)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3CrossAccountStateWrite",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::hcp-cmc-euw1-platform-tfstate-prd",
        "arn:aws:s3:::hcp-cmc-euw1-platform-tfstate-prd/hcp/prd/craighoad-website/*"
      ]
    }
  ]
}
```

## Migration Checklist

- [ ] Create centralized backend strategy document (this file)
- [ ] Update seed-terraform with all OIDC subject whitelists
- [ ] Create configs/orgs/myorg.tfvars template
- [ ] Add configs/orgs/myorg.tfvars to all platform repositories
- [ ] Update backend.tf in all repositories
- [ ] Add cross-account bucket policy for craighoad.com
- [ ] Migrate state files from old bucket to new bucket
- [ ] Update GitHub environment secrets
- [ ] Update GitHub Actions workflows
- [ ] Test parallel terraform execution
- [ ] Decomission old state bucket
- [ ] Document migration completion
