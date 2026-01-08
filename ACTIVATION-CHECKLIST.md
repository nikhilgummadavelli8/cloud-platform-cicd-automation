# Platform Activation Checklist

This checklist provides step-by-step instructions to activate the CI/CD platform from scratch. Follow each step in order and verify success before proceeding.

**Time Required:** 45-60 minutes (first-time activation)  
**Prerequisites:** Azure subscription, GitHub repository admin access

---

## Pre-Activation Requirements

Before starting, ensure you have:

- [ ] **Azure Subscription** with active credits or billing
- [ ] **Azure CLI** installed and working (`az --version`)
- [ ] **Terraform** >= 1.6 installed (`terraform version`)
- [ ] **Git** installed and configured
- [ ] **GitHub Repository** cloned locally
- [ ] **Azure Permissions:**
  - Contributor role on subscription (or resource group)
  - User Access Administrator (for RBAC assignments)
  - Ability to create Azure AD applications

**Verify Prerequisites:**
```bash
az --version        # Should show Azure CLI version
terraform version   # Should show >= 1.6
git status          # Should show clean working directory
```

---

## Activation Steps

### Step 1: Authenticate to Azure

```bash
# Login to Azure
az login

# List subscriptions and select the correct one
az account list --output table

# Set active subscription
az account set --subscription "your-subscription-id"

# Verify you're in the right subscription
az account show
```

**Verification:** `az account show` displays your target subscription.

---

### Step 2: Configure Terraform Variables

```bash
# Navigate to Terraform directory
cd infra/terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration with your values
# Use your favorite editor (nano, vim, code, etc.)
```

**Edit `terraform.tfvars`:**
```hcl
# Required: Your Azure subscription ID
azure_subscription_id = "00000000-0000-0000-0000-000000000000"  # From Step 1

# Required: Azure region
azure_location = "eastus"  # Or your preferred region

# Required: GitHub details
github_organization = "your-github-org-or-username"
github_repository   = "cloud-platform-cicd-automation"

# Optional: Customize resource names
resource_prefix     = "cicdplatform"
```

**Verification:** `cat terraform.tfvars` shows your configuration (no placeholder values remain).

---

### Step 3: Initialize Terraform

```bash
# Still in infra/terraform directory
terraform init
```

**Expected Output:**
```
Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "~> 3.0"...
- Finding hashicorp/azuread versions matching "~> 2.0"...
- Installing hashicorp/azurerm v3.x.x...
- Installing hashicorp/azuread v2.x.x...

Terraform has been successfully initialized!
```

**Verification:** `.terraform/` directory created, no errors displayed.

---

### Step 4: Preview Infrastructure Changes

```bash
terraform plan
```

**Expected Output:**
```
Plan: 10 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + acr_login_server    = (known after apply)
  + azure_client_id     = (known after apply)
  + key_vault_name      = (known after apply)
  ...
```

**Review Carefully:**
- [ ] ~10 resources will be created
- [ ] Resource names use your `resource_prefix`
- [ ] OIDC subject claim matches your `github_organization/github_repository`
- [ ] No errors or warnings

**Verification:** Plan shows expected resources, no errors.

---

### Step 5: Apply Infrastructure

```bash
terraform apply
```

**Prompt:** Type `yes` when asked to confirm.

**Duration:** 2-5 minutes

**Expected Output:**
```
Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

Outputs:
acr_login_server = "cicdplatformacr4j8k2m.azurecr.io"
acr_name = "cicdplatformacr4j8k2m"
azure_client_id = "33333333-3333-3333-3333-333333333333"
azure_subscription_id = "22222222-2222-2222-2222-222222222222"
azure_tenant_id = "11111111-1111-1111-1111-111111111111"
key_vault_name = "cicdplatform-kv-8n3p1x"
key_vault_uri = "https://cicdplatform-kv-8n3p1x.vault.azure.net/"
resource_group_name = "cicd-platform-rg"
```

**Verification:** No errors, outputs displayed successfully.

---

### Step 6: Capture Terraform Outputs

```bash
# Save outputs for reference
terraform output > outputs.txt

# Or view specific values
terraform output azure_client_id
terraform output azure_tenant_id
terraform output azure_subscription_id
terraform output acr_login_server
terraform output acr_name
terraform output key_vault_name
```

**Keep These Values:** You'll need them for GitHub secrets configuration.

**Verification:** All outputs display valid values (no "null" or empty strings).

---

### Step 7: Configure GitHub Secrets

Navigate to your GitHub repository:
**Settings → Secrets and variables → Actions → New repository secret**

Add these **6 secrets** using values from Step 6:

| Secret Name | Terraform Output Command | Example Value |
|-------------|--------------------------|---------------|
| `AZURE_CLIENT_ID` | `terraform output azure_client_id` | `33333333-3333-3333-...` |
| `AZURE_TENANT_ID` | `terraform output azure_tenant_id` | `11111111-1111-1111-...` |
| `AZURE_SUBSCRIPTION_ID` | `terraform output azure_subscription_id` | `22222222-2222-2222-...` |
| `ACR_LOGIN_SERVER` | `terraform output acr_login_server` | `cicdplatformacr4j8k2m.azurecr.io` |
| `ACR_NAME` | `terraform output acr_name` | `cicdplatformacr4j8k2m` |
| `KEY_VAULT_NAME` | `terraform output key_vault_name` | `cicdplatform-kv-8n3p1x` |

**Verification:** All 6 secrets visible in GitHub Settings → Secrets.

---

### Step 8: Re-enable Azure Pre-Flight Check

```bash
# Return to repository root
cd ../..

# Edit workflow file
# Find this section in .github/workflows/cicd-platform.yml:

# BEFORE (currently disabled):
  azure-preflight:
    name: Azure Pre-Flight Validation
    runs-on: ubuntu-latest
    needs: validate-inputs
    if: false  # <-- Remove this line
    permissions:
      id-token: write
      contents: read

# AFTER (enabled):
  azure-preflight:
    name: Azure Pre-Flight Validation
    runs-on: ubuntu-latest
    needs: validate-inputs
    permissions:
      id-token: write
      contents: read
```

Also update the `validate` job dependency:
```yaml
# BEFORE:
    needs: [validate-inputs]  # azure-preflight removed (temporarily disabled)

# AFTER:
    needs: [validate-inputs, azure-preflight]
```

**Commit and push the change:**
```bash
git add .github/workflows/cicd-platform.yml
git commit -m "Re-enable Azure pre-flight validation after activation"
git push
```

**Verification:** Workflow file updated and pushed to GitHub.

---

### Step 9: Trigger Test Workflow

```bash
# Option A: Push an empty commit
git commit --allow-empty -m "Test platform activation"
git push

# Option B: Use GitHub UI
# Go to Actions → Select workflow → Run workflow
```

**Verification:** Workflow run triggered on GitHub Actions page.

---

### Step 10: Verify Successful Activation

**Watch the workflow run:** GitHub → Actions → Latest run

**Check these jobs pass:**

- [ ] ✅ **Validate Workflow Inputs** - Passes
- [ ] ✅ **Azure Pre-Flight Validation** - Passes (all steps green)
  - Check Azure Configuration Status
  - Validate Azure OIDC Authentication
  - Validate ACR Access
  - Validate Key Vault Access
- [ ] ✅ **Validate Branch and Environment Mapping** - Passes
- [ ] ✅ **Security Enforcement** - Passes
- [ ] ✅ **Build** - Passes (or skipped if placeholder)
- [ ] ✅ **Test** - Passes (or skipped if placeholder)
- [ ] ✅ **Scan** - Passes (or skipped if placeholder)

**Success Criteria:**

```
✅ AZURE PRE-FLIGHT SUMMARY
============================================

Authentication: success
ACR Access: success
Key Vault Access: success

✅ Platform is ACTIVATED and ready for CI/CD operations
```

**Verification:** All pre-flight checks pass, workflow completes successfully.

---

## Post-Activation Verification

### Verify Azure Resources

```bash
# Check resource group exists
az group show --name cicd-platform-rg

# Check ACR is accessible
az acr list --output table

# Check Key Vault is accessible
az keyvault list --output table

# List role assignments
az role assignment list --all --output table | grep cicd
```

**Verification:** All resources exist and are accessible.

### Verify OIDC Federation

Azure Portal:
1. Navigate to **Azure Active Directory**
2. Go to **App registrations**
3. Find your application (e.g., "cicdplatform-github-actions")
4. Click **Federated credentials**
5. Verify credential exists:
   - Issuer: `https://token.actions.githubusercontent.com`
   - Subject: `repo:your-org/your-repo:environment:*` (or branch pattern)
   - Audience: `api://AzureADTokenExchange`

**Verification:** Federated credential configured correctly.

---

## What Success Looks Like

After successful activation:

✅ **Terraform state is clean:** `terraform show` displays all resources  
✅ **GitHub secrets configured:** 6 secrets visible in repository settings  
✅ **Workflows run successfully:** Azure pre-flight checks pass  
✅ **OIDC authentication works:** No authentication errors in logs  
✅ **ACR accessible:** Platform can login to container registry  
✅ **Key Vault accessible:** Platform can read secrets  

**You can now:**
- Build and deploy applications using the platform
- Enforce security and promotion gates
- Audit all deployments via GitHub Actions logs
- Operate without static credentials

---

## Troubleshooting Activation Failures

### Issue: `terraform apply` fails with "Unauthorized"

**Cause:** Insufficient Azure permissions  
**Fix:**
```bash
# Check your role assignments
az role assignment list --assignee $(az account show --query user.name -o tsv)

# You need: Contributor + User Access Administrator (or Owner)
```

---

### Issue: Azure Pre-Flight fails with "Authentication failed"

**Cause:** OIDC federation not configured correctly  
**Fix:**
1. Verify federated credential in Azure Portal (see Post-Activation Verification)
2. Ensure subject claim matches your repository exactly
3. Wait 5-10 minutes for Azure AD propagation
4. Re-run workflow

---

### Issue: ACR Access Denied

**Cause:** RBAC not propagated or role assignment missing  
**Fix:**
```bash
# Verify role assignment
az role assignment list --scope $(terraform output -raw acr_id)

# Wait 5-10 minutes for RBAC propagation
# Re-run workflow
```

---

### Issue: GitHub Secrets Missing

**Cause:** Secrets not configured or incorrect values  
**Fix:**
1. Go to GitHub Settings → Secrets
2. Delete incorrect secrets
3. Re-add with correct values from `terraform output`
4. Verify spelling matches exactly (case-sensitive)

---

## Rollback Procedure

If activation fails and you need to start over:

```bash
cd infra/terraform

# Destroy all Azure resources
terraform destroy  # Type 'yes' to confirm

# Remove GitHub secrets
# Manually delete via GitHub Settings → Secrets

# Start over from Step 1
```

**Warning:** `terraform destroy` deletes ALL resources including any data in ACR or Key Vault.

---

## Next Steps After Activation

1. **Create GitHub Environments:**
   - See `docs/activation/github-environments-setup.md`
   - Configure production with required reviewers

2. **Test End-to-End Flow:**
   - Create a feature branch
   - Push code
   - Watch it flow: Build → Test → Deploy to Dev

3. **Onboard First Application:**
   - Copy `pipeline-skeleton.yml` to application repo
   - Update `service_name`
   - Test deployment

4. **Monitor and Operate:**
   - Review [OPERATIONS.md](./OPERATIONS.md)
   - Set up alerts for failed workflows
   - Establish on-call rotation

---

**Platform Status:** Activated and Operational  
**Support:** See [OPERATIONS.md](./OPERATIONS.md) for troubleshooting  
**Documentation:** `docs/` directory for architecture and design details
