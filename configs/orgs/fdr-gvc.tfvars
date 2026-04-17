# Org Details
org             = "fedramp"
partition       = "aws-us-gov"
aws_region      = "us-gov-west-1"
environment     = "prd"
system          = "infra-cloudops"
organization_id = "o-xw1sf1ys1r"

# Guardrails — plan fails if credentials target the wrong account or region
expected_account_id = "415306063968"
expected_region     = "us-gov-west-1"

############################################
# IAM
############################################

member_role_path_prefix = "/"

############################################
# GITHUB / OIDC
############################################

# Teams that must approve deployments in the fdr-gvc-approve GitHub environment.
# Add team slugs to expand the approver group — create-gh-env.sh resolves them to IDs.
github_approver_teams = ["is-cloudops"]

# Subjects for the GitHub Actions OIDC trust policy.
# Format: repo:<github-org>/<repo>:environment:<tfvars-filename>
# The bootstrap script derives these automatically — keep in sync here for Terraform.
github_oidc_subjects = [
  # Seed pipeline (self)
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-tenant-seed:ref:refs/heads/main",
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-tenant-seed:environment:fdr-gvc",
  # Inventory export
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-inventory-export:ref:refs/heads/main",
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-inventory-export:environment:fdr-gvc",
  # Org analytics pipeline
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-org-analytics-pipeline:ref:refs/heads/main",
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-org-analytics-pipeline:environment:fdr-gvc",
  # Org analytics NLQ
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-org-analytics-nlq:environment:fdr-gvc",
  # Org analytics realtime
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-org-analytics-realtime:ref:refs/heads/main",
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-org-analytics-realtime:environment:fdr-gvc"
]

############################################
# STACKSET
############################################

target_organizational_unit_ids = [
  "ou-2s4o-wl0k6dbb", # BTP
  "ou-2s4o-pypp5no1", # infrastructure
  "ou-2s4o-80wwmcj9", # management
  "ou-2s4o-4g7o2q4w", # organization
  "ou-2s4o-8wde9ezf"  # production
]

############################################
# TAGGING
############################################

default_tags = {
  managed-by  = "terraform"
  bootstrap   = "true"
  owner       = "infra-cloudops"
  environment = "fedramp"
  partition   = "gvc"
}
