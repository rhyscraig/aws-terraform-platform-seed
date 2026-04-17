#!/usr/bin/env bash
# ============================================================
# BOOTSTRAP + IMPORT — myorg
#
# Phase 1: Creates AWS seed resources (runs anywhere — CloudShell,
#          local machine, CI).
# Phase 2: Imports resources into Terraform state.  Auto-installs
#          terraform if needed and clones the repo into /tmp/seed-repo.
#          Requires GITHUB_TOKEN env var for private repos.
#
# Usage (CloudShell or local):
#   export GITHUB_TOKEN=ghp_yourtoken
#   bash myorg-bootstrap.sh
# ============================================================
set -euo pipefail

########################################
# CONFIG (generated from configs/orgs/myorg.tfvars)
########################################

AWS_REGION="eu-west-1"
PARTITION="aws"
ORG="hcp"
ROLE_NAME="hcp-cmc-euw1-platform-oidc-role"
TF_STATE_BUCKET="hcp-cmc-euw1-platform-tfstate-prd"
TF_LOGS_BUCKET="hcp-cmc-euw1-platform-logs-prd"
KMS_ALIAS="alias/hcp-cmc-euw1-platform-tfstate"
NAME_PREFIX="hcp-cmc-euw1-platform"
TFVARS_BASENAME="myorg"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

########################################
# PHASE 1 — AWS RESOURCE CREATION
########################################

echo ""
echo "════════════════════════════════════════"
echo " PHASE 1: AWS resource creation"
echo "════════════════════════════════════════"

OIDC_URL="https://token.actions.githubusercontent.com"
OIDC_HOST="token.actions.githubusercontent.com"

echo "[INFO] Ensuring OIDC provider exists"

if aws iam get-open-id-connect-provider   --open-id-connect-provider-arn "arn:${PARTITION}:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_HOST}" >/dev/null 2>&1; then
  echo "[INFO] OIDC provider already exists"
else
  THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"  # pragma: allowlist secret

  aws iam create-open-id-connect-provider     --url "$OIDC_URL"     --client-id-list "sts.amazonaws.com"     --thumbprint-list "$THUMBPRINT"     >/dev/null

  echo "[INFO] OIDC provider created"
fi

cat > trust-policy.json <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:${PARTITION}:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_HOST}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_HOST}:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "${OIDC_HOST}:sub": ["repo:rhyscraig/aws-terraform-platform-seed:ref:refs/heads/main", "repo:rhyscraig/aws-terraform-platform-seed:environment:myorg"]
        }
      }
    }
  ]
}
POLICY

echo "[INFO] Ensuring role exists: $ROLE_NAME"

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "[INFO] Role exists, updating trust policy"
  aws iam update-assume-role-policy     --role-name "$ROLE_NAME"     --policy-document file://trust-policy.json
else
  echo "[INFO] Creating role"
  aws iam create-role     --role-name "$ROLE_NAME"     --assume-role-policy-document file://trust-policy.json     --description "OIDC bootstrap role for Terraform" >/dev/null
fi

cat > seed-policy.json <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["iam:*", "sts:*", "s3:*", "kms:*", "cloudformation:*", "organizations:*"],
      "Resource": "*"
    }
  ]
}
POLICY

echo "[INFO] Attaching bootstrap policy"
aws iam put-role-policy   --role-name "hcp-cmc-euw1-platform-oidc-role"   --policy-name "terraform-bootstrap"   --policy-document file://seed-policy.json   >/dev/null

echo "[INFO] Ensuring KMS key exists"
KMS_KEY_ID=$(aws kms list-aliases   --query "Aliases[?AliasName=='${KMS_ALIAS}'].TargetKeyId | [0]"   --output text)

if [[ "$KMS_KEY_ID" == "None" || -z "$KMS_KEY_ID" ]]; then
  echo "[INFO] Creating KMS key"
  KMS_KEY_ID=$(aws kms create-key     --description "${NAME_PREFIX}-tf-state-key"     --query KeyMetadata.KeyId     --output text)
  echo "[INFO] Creating KMS alias"
  aws kms create-alias     --alias-name "${KMS_ALIAS}"     --target-key-id "$KMS_KEY_ID"
else
  echo "[INFO] KMS key exists"
fi

create_bucket() {
  local bucket="$1"
  if aws s3api head-bucket --bucket "$bucket" >/dev/null 2>&1; then
    echo "[INFO] Bucket exists: $bucket"
  else
    echo "[INFO] Creating bucket: $bucket"
    aws s3api create-bucket       --bucket "$bucket"       --region "eu-west-1"       $( [[ "eu-west-1" != "us-east-1" ]] && echo "--create-bucket-configuration LocationConstraint=eu-west-1" )       >/dev/null
  fi
}

create_bucket "hcp-cmc-euw1-platform-tfstate-prd"
create_bucket "hcp-cmc-euw1-platform-logs-prd"

echo "[INFO] Enabling versioning on state bucket"
aws s3api put-bucket-versioning   --bucket "hcp-cmc-euw1-platform-tfstate-prd"   --versioning-configuration Status=Enabled   >/dev/null

echo "[INFO] Enabling KMS encryption on state bucket"
aws s3api put-bucket-encryption   --bucket "hcp-cmc-euw1-platform-tfstate-prd"   --server-side-encryption-configuration "{
    \"Rules\": [{
      \"ApplyServerSideEncryptionByDefault\": {
        \"SSEAlgorithm\": \"aws:kms\",
        \"KMSMasterKeyID\": \"$KMS_KEY_ID\"
      },
      \"BucketKeyEnabled\": true
    }]
  }"   >/dev/null

########################################
# HELPER — print exports (called at end and on token error)
########################################

print_exports() {
  echo ""
  echo "════════════════════════════════════════"
  echo " Copy these exports to your local terminal"
  echo "════════════════════════════════════════"
  echo "export SEED_ROLE_ARN=\"arn:${PARTITION}:iam::${ACCOUNT_ID}:role/${ROLE_NAME}\""
  echo "export TF_STATE_BUCKET=\"${TF_STATE_BUCKET}\""
  echo "export TF_LOGS_BUCKET=\"${TF_LOGS_BUCKET}\""
  echo "export KMS_ALIAS=\"${KMS_ALIAS}\""
  echo "export KMS_KEY_ID=\"${KMS_KEY_ID}\""
  echo "export AWS_REGION=\"${AWS_REGION}\""
  echo "export AWS_DEFAULT_REGION=\"${AWS_REGION}\""
  echo ""
}

########################################
# PHASE 2 — TERRAFORM IMPORTS
########################################

echo ""
echo "════════════════════════════════════════"
echo " PHASE 2: Terraform state imports"
echo "════════════════════════════════════════"

########################################
# INSTALL TERRAFORM (if needed)
########################################

TF_VERSION="1.14.5"
if ! command -v terraform >/dev/null 2>&1; then
  echo "[INFO] Installing terraform ${TF_VERSION}..."
  TF_ARCH="$(uname -m)"
  [[ "${TF_ARCH}" == "x86_64" ]] && TF_ARCH="amd64" || TF_ARCH="arm64"
  curl -sLo /tmp/terraform.zip     "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${TF_ARCH}.zip"
  mkdir -p "${HOME}/bin"
  unzip -q -o /tmp/terraform.zip -d "${HOME}/bin"
  rm /tmp/terraform.zip
  export PATH="${HOME}/bin:${PATH}"
  echo "[INFO] Installed: $(terraform version | head -1)"
else
  echo "[INFO] Terraform already available: $(terraform version | head -1)"
fi

########################################
# CLONE REPO (if needed)
########################################

REPO_HTTPS="https://github.com/rhyscraig/aws-terraform-platform-seed"
REPO_DIR="/tmp/seed-repo"

GITHUB_TOKEN="${GITHUB_TOKEN:-}"
if [[ -z "${GITHUB_TOKEN}" ]]; then
  echo ""
  echo "════════════════════════════════════════"
  echo " ❌  GITHUB_TOKEN required for Phase 2"
  echo "════════════════════════════════════════"
  echo ""
  echo "Run this command on your LOCAL machine to get the exact export:"
  echo ""
  echo '   echo "export GITHUB_TOKEN=$(gh auth token)"'
  echo ""
  echo "Copy the output it prints, paste it here in CloudShell, then re-run:"
  echo ""
  echo "   bash $0"
  echo ""
  print_exports
  echo "✅ Phase 1 complete. Re-run with GITHUB_TOKEN set to complete Phase 2."
  exit 0
fi

if [[ ! -d "${REPO_DIR}/seed-terraform" ]]; then
  echo "[INFO] Cloning repository..."
  git clone "https://${GITHUB_TOKEN}@${REPO_HTTPS#https://}" "${REPO_DIR}"
  echo "[INFO] Repository cloned to ${REPO_DIR}"
else
  echo "[INFO] Repository already present at ${REPO_DIR}, pulling latest..."
  git -C "${REPO_DIR}" remote set-url origin "https://${GITHUB_TOKEN}@${REPO_HTTPS#https://}"
  git -C "${REPO_DIR}" pull
fi

cd "${REPO_DIR}"

echo "[INFO] Configuring git credentials for private modules..."
git config --global url."https://${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"

echo "[INFO] Waiting 10s for IAM propagation..."
sleep 10

echo "[INFO] Initialising Terraform backend"
terraform -chdir=seed-terraform init -input=false -reconfigure -lock-timeout=60s   -backend-config="bucket=${TF_STATE_BUCKET}"   -backend-config="key=myorg/${PARTITION}/control-plane/terraform.tfstate"   -backend-config="region=${AWS_REGION}"   -backend-config="encrypt=true"   -backend-config="kms_key_id=${KMS_KEY_ID}"

VARFILE="$(pwd)/configs/orgs/${TFVARS_BASENAME}.tfvars"

tf_import() {
  local address="$1"
  local id="$2"
  if terraform -chdir=seed-terraform state show "${address}" >/dev/null 2>&1; then
    echo "  [SKIP] already in state: ${address}"
  else
    echo "  [IMPORT] ${address}"
    terraform -chdir=seed-terraform import       -input=false       -var-file="${VARFILE}"       "${address}" "${id}"
  fi
}

echo "[INFO] Importing 7 bootstrap resources..."

echo "[1/7] OIDC provider"
tf_import   "module.oidc_provider.aws_iam_openid_connect_provider.this[0]"   "arn:${PARTITION}:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

echo "[2/7] OIDC role"
tf_import   "module.workloads_oidc_role.aws_iam_role.this[0]"   "${NAME_PREFIX}-oidc-role"

echo "[3/7] State bucket"
tf_import   "module.state_bucket[0].aws_s3_bucket.this[0]"   "${TF_STATE_BUCKET}"

echo "[4/7] Logs bucket"
tf_import   "module.logs_bucket[0].aws_s3_bucket.this[0]"   "${TF_LOGS_BUCKET}"

echo "[5/7] KMS key"
tf_import   "module.kms_key.aws_kms_key.this[0]"   "${KMS_KEY_ID}"

echo "[6/7] KMS alias"
tf_import   "module.kms_key.aws_kms_alias.this[\"hcp-cmc-euw1-platform-tfstate\"]"   "alias/hcp-cmc-euw1-platform-tfstate"

echo "[7/7] Assume member roles policy (only if pre-existing from a failed apply)"
POLICY_ARN="arn:${PARTITION}:iam::${ACCOUNT_ID}:policy/hcp-cmc-euw1-platform-assume-member-roles"
if aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
  tf_import     "module.assume_member_roles_policy.aws_iam_policy.policy[0]"     "${POLICY_ARN}"
else
  echo "  [SKIP] policy does not exist yet, Terraform will create it"
fi

echo ""
echo "[INFO] Resources in state:"
terraform -chdir=seed-terraform state list

echo ""
echo "✅ Bootstrap + imports complete."
print_exports
echo "Next steps:"
echo "  1. Copy the exports above to your local terminal"
echo "  2. Export secrets to GitHub:"
echo "       make create-github-environment ORG=myorg"
echo "  3. Trigger the GitHub Actions workflow:"
echo "       terraform-deploy.yml → org: myorg"
