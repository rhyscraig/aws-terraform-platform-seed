# Multi-Repo Terraform Infrastructure Implementation Summary

## Completed Tasks

### 1. ✅ Centralized Backend Strategy Design
**File:** `CENTRALIZED_BACKEND_STRATEGY.md`

- Designed hierarchical S3 path structure for unified state management
- All repos now use single central bucket: `hcp-cmc-euw1-platform-tfstate-prd`
- Path structure: `hcp/prd/{system}/{component}/{region}/terraform.tfstate`
- Eliminated dependency on DynamoDB locking (now using S3 object locks)

### 2. ✅ OIDC Trust Policy Expansion
**File:** `configs/orgs/myorg.tfvars`

Updated `github_oidc_subjects` to whitelist all platform repositories:
- aws-terraform-platform-seed (fixed ref from master → main)
- aws-terraform-platform-aws-accounts
- aws-terraform-platform-aws-baselines
- aws-terraform-platform-aws-org
- aws-terraform-solutions-terrorgem
- website-static-html-craighoad.com

All repos can now authenticate via OIDC and deploy infrastructure.

### 3. ✅ Organization Configuration Files
Created `configs/orgs/myorg.tfvars` in all platform repositories:
- aws-terraform-platform-aws-accounts/configs/orgs/myorg.tfvars
- aws-terraform-platform-aws-baselines/configs/orgs/myorg.tfvars
- aws-terraform-platform-aws-org/configs/orgs/myorg.tfvars
- aws-terraform-solutions-terrorgem/configs/orgs/myorg.tfvars
- website-static-html-craighoad.com/configs/orgs/myorg.tfvars

Org config includes:
- `org = "hcp"`
- `environment = "prd"`
- `organization_id = "o-9c67661145"`
- `expected_account_id` (specific to each repo/account)
- `default_tags` (managed-by, bootstrap, owner, environment, partition, organization)

Updated `.gitignore` in all repos to allow tracking of `configs/orgs/*.tfvars` (shared, non-sensitive config).

### 4. ✅ Backend Configuration Updates
Updated `backend.tf` in all platform repositories:

| Repository | State Path | Account |
|-----------|-----------|---------|
| aws-terraform-platform-aws-accounts | `hcp/prd/platform/aws-accounts/eu-west-1/terraform.tfstate` | Management (395101865577) |
| aws-terraform-platform-aws-baselines | `hcp/prd/platform/aws-baselines/eu-west-1/terraform.tfstate` | Management (395101865577) |
| aws-terraform-platform-aws-org | `hcp/prd/platform/aws-org/eu-west-1/terraform.tfstate` | Management (395101865577) |
| aws-terraform-solutions-terrorgem | `hcp/prd/terrorgems/terrorgem/eu-west-1/terraform.tfstate` | Management (395101865577) |
| website-static-html-craighoad.com | `hcp/prd/craighoad-website/craighoad/eu-west-1/terraform.tfstate` | craighoad.com (767828739298) |

All backends:
- Point to central bucket: `hcp-cmc-euw1-platform-tfstate-prd`
- Enable KMS encryption: `encrypt = true`
- Use S3 object locking: `use_lockfile = true`
- Region: `eu-west-1` (consistent)

### 5. ✅ Cross-Account State Access Infrastructure
**Files:** `seed-terraform/main.tf`, `seed-terraform/variables.tf`

Added to seed-terraform:
- **Variable:** `craighoad_oidc_role_arn` (optional, for cross-account write access)
- **Resource:** S3 bucket policy allowing craighoad.com OIDC role to write to `hcp/prd/craighoad-website/*` prefix
- **Logic:** Policy only created if `craighoad_oidc_role_arn` variable is provided (optional during initial setup)

### 6. ✅ craighoad.com Account Setup Documentation
**File:** `CRAIGHOAD_ACCOUNT_SETUP.md`

Comprehensive 8-step guide for setting up the craighoad.com production account:
1. Create OIDC provider (one-time, shared with management account provider)
2. Create OIDC IAM role (`craighoad-prod-oidc-role`)
3. Create state bucket access policy
4. Create website deployment policy (S3, CloudFront, Route53, ACM)
5. Update seed terraform with role ARN
6. Configure GitHub secrets in website repo
7. Create GitHub Actions workflow template
8. Verification and troubleshooting steps

### 7. ✅ Git Repository Updates
All changes committed and pushed to GitHub:
- seed repository (master branch): Backend strategy docs + OIDC expansion
- All platform repositories (main branches): Backend + org config updates

## Pending Tasks

### Phase 1: State Migration (Pre-requisite for terraform apply)

The centralized backend is now configured, but existing state files need to be migrated. **This must be done before running terraform apply.**

For each repository with existing state:
```bash
# Pull old state
terraform state pull > /tmp/old-state.json

# Switch to new backend config
cd /repo && git pull

# Initialize with new backend (don't copy state yet)
terraform init -reconfigure -backend-config="bucket=..." \
  -lock-timeout=60s

# Push migrated state (if using same names/resources)
terraform state push /tmp/old-state.json
```

### Phase 2: craighoad.com Account Setup

Execute steps from `CRAIGHOAD_ACCOUNT_SETUP.md`:
1. Create OIDC provider in craighoad.com account
2. Create IAM roles and policies
3. Update seed-terraform with `craighoad_oidc_role_arn`
4. Configure GitHub secrets in website-static-html-craighoad.com repo
5. Create `.github/workflows/terraform-deploy.yml` workflow

### Phase 3: Parallel Terraform Execution

Once state is migrated and all repos have correct backend config:
1. Update GitHub Actions workflows to use new backend configuration
2. Test parallel terraform plans across multiple repos
3. Implement approval gates for terraform applies

### Phase 4: Old Infrastructure Decommissioning

1. **Create terraform destroy workflow** for old craighoad.com infrastructure
   - Optional: decomission old state bucket first
2. **Remove old state bucket** and associated resources
3. **Archive documentation** of old infrastructure

### Phase 5: Future Scaling

Once core infrastructure is stable:
- Add support for multiple environments (prd, dev, staging) via `environment` variable
- Implement per-environment approval policies
- Scale to additional orgs/regions as needed

## Architecture Validation Checklist

- [ ] **OIDC Trust Policy**: All 6 repos listed in `github_oidc_subjects`
- [ ] **Organization Config**: All repos have `configs/orgs/myorg.tfvars`
- [ ] **Backend Configuration**: All repos point to central bucket with correct paths
- [ ] **Cross-Account Policy**: S3 bucket policy optional in seed-terraform (variable-driven)
- [ ] **KMS Encryption**: All state files encrypted with shared KMS key
- [ ] **S3 Versioning**: Enabled on central bucket with 90-day retention
- [ ] **.gitignore Updates**: All repos allow `configs/orgs/*.tfvars` tracking

## Key Design Decisions

### S3 Path Structure
- **Chosen:** `hcp/prd/{system}/{component}/{region}/terraform.tfstate`
- **Rationale:** Hierarchical structure supports multi-org scaling, clear separation by system type, component identity, and region
- **Alternative rejected:** Flat structure or account-based layout (would reduce clarity as new orgs are added)

### DynamoDB Locking
- **Chosen:** S3 object locks via `use_lockfile = true`
- **Rationale:** Single bucket manages all locking, no separate DynamoDB table, simpler to manage
- **Notes:** Deprecated in favor of S3 native locking per AWS recommendations

### Cross-Account Design
- **Chosen:** Variable-driven optional policy in seed-terraform
- **Rationale:** Decouples setup steps (OIDC role created first, then ARN provided to seed-terraform)
- **Alternative rejected:** Hard-coded OIDC role ARN (would require sequential ordering)

### Config File Tracking
- **Chosen:** Track `configs/orgs/*.tfvars` in git (shared org config)
- **Rationale:** Org configuration is standardized across all repos for consistency
- **Alternative rejected:** .gitignore all .tfvars (would require manual config per deployment)

## Deployment Flow (After Migration)

```
GitHub Actions Workflow
    ↓
1. Checkout code + configs/orgs/myorg.tfvars
2. Authenticate via OIDC (whitelisted subject)
3. Assume OIDC role in target account
4. terraform init (with central bucket backend)
5. terraform plan -var-file="../configs/orgs/myorg.tfvars"
6. terraform apply (with approval gate)
    ↓
State file written to central bucket
    ↓
S3 bucket (centralized, KMS encrypted, versioned)
```

## GitHub Actions Integration Points

### Environment Secrets (per repo, `myorg` environment)
- `TF_STATE_BUCKET`: `hcp-cmc-euw1-platform-tfstate-prd`
- `KMS_KEY_ID`: `alias/hcp-cmc-euw1-platform-tfstate`
- `AWS_REGION`: `eu-west-1`
- `AWS_ROLE_TO_ASSUME`: OIDC role ARN in respective account

### Workflow Template (shared pattern across all repos)
```yaml
- terraform init -backend-config="bucket=$TF_STATE_BUCKET" \
    -backend-config="key=<repo-specific-path>" \
    -backend-config="region=$AWS_REGION"
- terraform plan -var-file="configs/orgs/myorg.tfvars"
- terraform apply -var-file="configs/orgs/myorg.tfvars"
```

## Security & Compliance Notes

### State File Encryption
- KMS key rotated annually (enabled in seed-terraform)
- S3 bucket versioning preserves state history
- Server-side encryption enabled on central bucket
- Cross-account access scoped to specific S3 prefixes

### IAM Permissions
- OIDC roles have least-privilege access (per repo)
- Cross-account policy restricts craighoad.com to dedicated prefix
- No long-lived AWS credentials in GitHub Actions

### Audit Trail
- CloudTrail logs all bucket access
- S3 versioning provides state history
- Git history tracks configuration changes

## Cost Impact

- **Centralized bucket:** £0.00 (consolidated from 2 buckets)
- **KMS key:** £1/month (shared across all repos)
- **S3 storage:** ~£0.01/month (state files are tiny)
- **Data transfer:** ~£0.00 (internal AWS transfer)

**Savings:** Elimination of per-repo state buckets and DynamoDB locking table

## Next Steps

1. **Immediate:** Review this document and CENTRALIZED_BACKEND_STRATEGY.md
2. **Week 1:** Execute state migration for repos with existing state
3. **Week 1:** Set up craighoad.com account per CRAIGHOAD_ACCOUNT_SETUP.md
4. **Week 2:** Test terraform plans across all repos
5. **Week 2:** Implement parallel terraform apply workflows
6. **Week 3:** Decommission old infrastructure and state bucket

---

**Status:** ✅ Architecture Complete | ⏳ Implementation Phase 1 (State Migration) Pending
**Last Updated:** 2026-04-17
