# Org Details
org             = "fedramp"
partition       = "aws"
aws_region      = "us-east-1"
environment     = "prd"
system          = "infra-cloudops"
organization_id = "o-mdbva9lvps"

# Guardrails — plan fails if credentials target the wrong account or region
expected_account_id = "260278864911"
expected_region     = "us-east-1"

############################################
# IAM
############################################

member_role_path_prefix = "/"

############################################
# GITHUB / OIDC
############################################

# Teams that must approve deployments in the fdr-cmc-approve GitHub environment.
# Add team slugs to expand the approver group — create-gh-env.sh resolves them to IDs.
github_approver_teams = ["is-cloudops"]

# Subjects for the GitHub Actions OIDC trust policy.
# Format: repo:<github-org>/<repo>:environment:<tfvars-filename>
# The bootstrap script derives these automatically — keep in sync here for Terraform.
github_oidc_subjects = [
  # Seed pipeline (self)
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-tenant-seed:ref:refs/heads/main",
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-tenant-seed:environment:fdr-cmc",
  # Inventory export
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-inventory-export:ref:refs/heads/main",
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-inventory-export:environment:fdr-cmc",
  # Org analytics pipeline
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-org-analytics-pipeline:ref:refs/heads/main",
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-org-analytics-pipeline:environment:fdr-cmc",
  # Org analytics NLQ
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-org-analytics-nlq:environment:fdr-cmc",
  # Org analytics realtime
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-org-analytics-realtime:ref:refs/heads/main",
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-org-analytics-realtime:environment:fdr-cmc"
]

############################################
# STACKSET
############################################

target_organizational_unit_ids = [
  "ou-bcqi-aw1nq0hd", # BTP
  "ou-bcqi-0cryuc0w", # infrastructure
  "ou-bcqi-inr9zkf1", # management
  "ou-bcqi-54ivz4xk", # organization
  "ou-bcqi-ukz7tq55"  # production
]

############################################
# TAGGING
############################################

default_tags = {
  managed-by  = "terraform"
  bootstrap   = "true"
  owner       = "infra-cloudops"
  environment = "fedramp"
  partition   = "cmc"
}
