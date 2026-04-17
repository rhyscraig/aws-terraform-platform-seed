# Org Details
org             = "bt"
partition       = "aws"
aws_region      = "us-east-1"
environment     = "prd"
system          = "infra-cloudops"
organization_id = ""

# Guardrails — plan fails if credentials target the wrong account or region
expected_account_id = ""
expected_region     = "us-east-1"

############################################
# IAM
############################################

member_role_path_prefix = "/"

############################################
# GITHUB / OIDC
############################################

# Teams that must approve deployments in the bt-avm-approve GitHub environment.
github_approver_teams = ["is-cloudops"]

# Subjects for the GitHub Actions OIDC trust policy.
# Format: repo:<github-org>/<repo>:environment:<tfvars-filename>
# The bootstrap script derives these automatically — keep in sync here for Terraform.
github_oidc_subjects = [
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-tenant-seed:ref:refs/heads/main",
  "repo:BT-IT-Infrastructure-CloudOps/aws-terraform-infra-cloudops-tenant-seed:environment:bt-avm"
]

############################################
# STACKSET
############################################

target_organizational_unit_ids = []

############################################
# TAGGING
############################################

default_tags = {
  managed-by  = "terraform"
  bootstrap   = "true"
  owner       = "platform"
  environment = "prd"
  partition   = "aws"
}
