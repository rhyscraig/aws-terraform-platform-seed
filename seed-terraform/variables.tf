########################################
# CORE IDENTIFIERS
########################################

variable "org" {
  type = string
  validation {
    condition     = length(var.org) > 1 && length(var.org) < 20
    error_message = "org must be between 2 and 20 characters"
  }
}

variable "system" {
  type = string
  validation {
    condition     = length(var.system) > 1 && length(var.system) < 20
    error_message = "system must be between 2 and 20 characters"
  }
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prd"], var.environment)
    error_message = "environment must be 'dev' or 'prd'"
  }
}

########################################
# AWS PARTITION + REGION
########################################

variable "partition" {
  type = string
  validation {
    condition     = contains(["aws", "aws-us-gov"], var.partition)
    error_message = "partition must be 'aws' or 'aws-us-gov'"
  }
}

variable "aws_region" {
  type = string
  validation {
    condition = contains([
      "us-east-1", "us-west-1", "us-west-2",
      "eu-west-1", "us-gov-east-1", "us-gov-west-1"
    ], var.aws_region)
    error_message = "Invalid AWS region"
  }
}

########################################
# OIDC + IAM
########################################

variable "github_oidc_subjects" {
  type = list(string)
  validation {
    condition     = length(var.github_oidc_subjects) > 0
    error_message = "At least one OIDC subject must be provided"
  }
}

variable "member_role_path_prefix" {
  type = string
  validation {
    condition     = can(regex("^/.*$", var.member_role_path_prefix))
    error_message = "member_role_path_prefix must start and end with '/'"
  }
}

########################################
# ORGANIZATION TARGETING
########################################

variable "target_organizational_unit_ids" {
  description = "OUs to deploy the member CI/CD role into via CloudFormation StackSet. When empty, the StackSet module is skipped entirely."
  type        = list(string)
  default     = []
}

########################################
# TAGGING
########################################

variable "default_tags" {
  type    = map(string)
  default = {}
}

########################################
# GITHUB (pipeline metadata — not used by Terraform, read by create-gh-env.sh)
########################################

# tflint-ignore: terraform_unused_declarations
variable "github_approver_teams" {
  description = "GitHub team slugs granted approval rights on the {org}-approve environment. Read by create-gh-env.sh — not used in Terraform resources."
  type        = list(string)
  default     = []
}

########################################
# GUARDRAILS
########################################

variable "expected_account_id" {
  description = "Guard rail: if set, plan fails if the authenticated account does not match"
  type        = string
  default     = ""
}

variable "expected_region" {
  description = "Guard rail: if set, plan fails if the authenticated region does not match"
  type        = string
  default     = ""
}


variable "organization_id" {
  description = "The org id"
  type        = string
}

########################################
# CROSS-ACCOUNT STATE BUCKET ACCESS
########################################

variable "craighoad_oidc_role_arn" {
  description = "ARN of the OIDC role in craighoad.com production account (for cross-account state bucket write access). Leave empty to skip cross-account policy."
  type        = string
  default     = ""
}

########################################
# ACCOUNT CREATION
########################################

variable "create_craighoad_account" {
  description = "Whether to create the craighoad.com production account. Set to true to create/manage the account via Terraform."
  type        = bool
  default     = false
}

variable "craighoad_account_email" {
  description = "Email address for the craighoad.com production account"
  type        = string
  default     = ""
}

variable "craighoad_account_name" {
  description = "Name for the craighoad.com production account"
  type        = string
  default     = "craighoad-com-production"
}

variable "craighoad_parent_ou_id" {
  description = "Parent OU ID for craighoad.com production account (workloads_prod_ou by default)"
  type        = string
  default     = ""
}

########################################
# AWS SSO CONFIGURATION
########################################

variable "sso_principal_id" {
  description = "AWS SSO principal ID (user or group) to assign to permission sets. Get from AWS Identity Center"
  type        = string
  default     = ""
}

variable "sso_principal_type" {
  description = "AWS SSO principal type: USER or GROUP"
  type        = string
  default     = "USER"
  validation {
    condition     = contains(["USER", "GROUP"], var.sso_principal_type)
    error_message = "sso_principal_type must be 'USER' or 'GROUP'"
  }
}
