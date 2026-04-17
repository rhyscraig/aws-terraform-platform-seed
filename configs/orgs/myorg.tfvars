# Org Details
org             = "hcp"
partition       = "aws"
aws_region      = "eu-west-1"
environment     = "prd"
system          = "platform"
organization_id = "o-9c67661145"

# Guardrails — plan fails if credentials target the wrong account or region
expected_account_id = "395101865577"
expected_region     = "eu-west-1"

############################################
# IAM
############################################

member_role_path_prefix = "/"

############################################
# GITHUB / OIDC
############################################

# Approver teams for GitHub Actions deployment environments
github_approver_teams = ["platform-engineers"]

# Subjects for the GitHub Actions OIDC trust policy.
# Format: repo:<github-org>/<repo>:environment:<tfvars-filename>
# The bootstrap script derives these automatically — keep in sync here for Terraform.
github_oidc_subjects = [
  # Seed pipeline (self)
  "repo:rhyscraig/aws-terraform-platform-seed:ref:refs/heads/master",
  "repo:rhyscraig/aws-terraform-platform-seed:environment:myorg",
  # Platform accounts AVM
  "repo:rhyscraig/aws-terraform-platform-aws-accounts:ref:refs/heads/main",
  "repo:rhyscraig/aws-terraform-platform-aws-accounts:environment:production",
  # Platform baselines
  "repo:rhyscraig/aws-terraform-platform-aws-baselines:ref:refs/heads/main",
  "repo:rhyscraig/aws-terraform-platform-aws-baselines:environment:production",
  # Platform org
  "repo:rhyscraig/aws-terraform-platform-aws-org:ref:refs/heads/main",
  "repo:rhyscraig/aws-terraform-platform-aws-org:environment:prod",
  # TerrorGems infrastructure
  "repo:rhyscraig/aws-terraform-solutions-terrorgem:ref:refs/heads/main",
  "repo:rhyscraig/aws-terraform-solutions-terrorgem:environment:prod"
]

############################################
# STACKSET
############################################

# Deploy member account access roles to all OUs
target_organizational_unit_ids = [
  "ou-9c67-g3p0lw4x", # management
  "ou-9c67-h7m9k2a1", # security_ou
  "ou-9c67-q1r8v5c3", # infrastructure_ou
  "ou-9c67-t2p4n6m8", # workloads_prod_ou
  "ou-9c67-x5k1j3l9"  # workloads_nonprod_ou
]

############################################
# TAGGING
############################################

default_tags = {
  managed-by  = "terraform"
  bootstrap   = "true"
  owner       = "platform"
  environment = "production"
  partition   = "hcp"
  organization = "myorg"
}
