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
# Format: repo:<github-org>/<repo>:ref:<ref> OR repo:<github-org>/<repo>:environment:<env-name>
# The bootstrap script derives these automatically — keep in sync here for Terraform.
github_oidc_subjects = [
  # Seed pipeline (self)
  "repo:rhyscraig/aws-terraform-platform-seed:ref:refs/heads/main",
  "repo:rhyscraig/aws-terraform-platform-seed:environment:myorg",

  # Platform - Accounts AVM
  "repo:rhyscraig/aws-terraform-platform-aws-accounts:ref:refs/heads/main",
  "repo:rhyscraig/aws-terraform-platform-aws-accounts:environment:myorg",

  # Platform - Baselines
  "repo:rhyscraig/aws-terraform-platform-aws-baselines:ref:refs/heads/main",
  "repo:rhyscraig/aws-terraform-platform-aws-baselines:environment:myorg",

  # Platform - Organization
  "repo:rhyscraig/aws-terraform-platform-aws-org:ref:refs/heads/main",
  "repo:rhyscraig/aws-terraform-platform-aws-org:environment:myorg",

  # Solutions - TerrorGems
  "repo:rhyscraig/aws-terraform-solutions-terrorgem:ref:refs/heads/main",
  "repo:rhyscraig/aws-terraform-solutions-terrorgem:environment:myorg",

  # Solutions - Website
  "repo:rhyscraig/website-static-html-craighoad.com:ref:refs/heads/main",
  "repo:rhyscraig/website-static-html-craighoad.com:environment:myorg"
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
# ACCOUNT CREATION
############################################

# Create craighoad.com production account
create_craighoad_account = true
craighoad_account_email  = "craighoad+craighoad-com@hotmail.com"
craighoad_account_name   = "craighoad-com-production"
craighoad_parent_ou_id   = "ou-9c67-t2p4n6m8" # workloads_prod_ou

############################################
# AWS SSO PERMISSION SETS
############################################

# Get your SSO principal ID from AWS Identity Center > Users or Groups > copy the ID
# This is your user or group ID in AWS SSO that will be assigned admin access to new accounts
sso_principal_id   = "00000000-0000-0000-0000-000000000000"  # CHANGE THIS: Your AWS SSO user/group ID
sso_principal_type = "USER"

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
