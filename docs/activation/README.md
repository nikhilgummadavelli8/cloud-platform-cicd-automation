# Platform Activation Guide

This CI/CD platform is **fully implemented** but **intentionally dormant** until Azure infrastructure is provisioned. This document explains how to activate the platform.

## Current State

✅ **Fully functional** - All workflows, contracts, and infrastructure code are complete  
⏸️ **Dormant** - Platform is not active until Azure credentials are provided  
🔒 **Secure** - No hardcoded credentials, uses OIDC federation  
📦 **Account-agnostic** - Works with any Azure subscription

## Prerequisites

Before activating the platform, ensure you have:

- [ ] **Azure Account** with an active subscription
- [ ] **Azure CLI** installed and authenticated (`az login`)
- [ ] **Terraform** >= 1.6 installed
- [ ] **GitHub Repository** admin access (to configure secrets)
- [ ] **Azure Permissions** to create:
  - Azure AD applications
  - Resource groups
  - Container Registry
  - Key Vault
  - Role assignments

## Quick Start

### 1. Configure Terraform Variables

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your Azure details:

```hcl
azure_subscription_id = "your-subscription-id"  # Run: az account show --query id
azure_location        = "eastus"
resource_prefix       = "cicdplatform"
environment           = "dev"

github_organization = "your-github-org"
github_repository   = "your-repo-name"
github_branch       = "main"
github_environment  = "*"  # or specific environment name
```

### 2. Provision Azure Infrastructure

```bash
terraform init
terraform plan   # Review what will be created
terraform apply  # Type 'yes' to create resources
```

This creates:
- Azure AD application for GitHub Actions
- OIDC federated identity credential
- Azure Container Registry (ACR)
- Azure Key Vault
- RBAC role assignments

### 3. Capture Terraform Outputs

```bash
terraform output
```

You'll see values like:
```
azure_client_id = "00000000-0000-0000-0000-000000000000"
azure_tenant_id = "11111111-1111-1111-1111-111111111111"
acr_login_server = "cicdplatformacr4j8k2m.azurecr.io"
key_vault_name = "cicdplatform-kv-8n3p1x"
```

### 4. Configure GitHub Secrets

Go to your GitHub repository:
**Settings → Secrets and variables → Actions → New repository secret**

Add these secrets:

| Secret Name | Value Source | Example |
|-------------|--------------|---------|
| `AZURE_CLIENT_ID` | `terraform output azure_client_id` | `00000000-0000-0000-...` |
| `AZURE_TENANT_ID` | `terraform output azure_tenant_id` | `11111111-1111-1111-...` |
| `AZURE_SUBSCRIPTION_ID` | `terraform output azure_subscription_id` | `22222222-2222-2222-...` |
| `ACR_LOGIN_SERVER` | `terraform output acr_login_server` | `myregistry.azurecr.io` |
| `ACR_NAME` | `terraform output acr_name` | `myregistryacr123` |
| `KEY_VAULT_NAME` | `terraform output key_vault_name` | `mykv-abc123` |

### 5. Test Activation

Push a commit or manually trigger the workflow:

```bash
git commit --allow-empty -m "Test platform activation"
git push
```

The **azure-preflight** job will validate:
- ✅ All required secrets are present
- ✅ OIDC authentication works
- ✅ ACR access is functional
- ✅ Key Vault access is functional

## What Happens After Activation

Once activated, the platform will:

1. **Authenticate via OIDC** - No static credentials, automatic token exchange
2. **Build & publish artifacts** - Container images pushed to ACR
3. **Retrieve secrets** - Runtime secrets from Key Vault
4. **Deploy to environments** - Based on branch and promotion rules
5. **Enforce all standards** - Immutability, traceability, security

## Validation Checklist

After activation, verify:

- [ ] Workflow runs without "Azure not activated" errors
- [ ] Azure pre-flight job passes (green check)
- [ ] OIDC authentication succeeds
- [ ] ACR login succeeds
- [ ] Key Vault access succeeds
- [ ] No static credentials in logs

## Troubleshooting

### ❌ "Azure not activated" error

**Cause:** Required GitHub secrets are missing  
**Fix:** Complete Step 4 above - configure all 6 secrets

---

### ❌ "OIDC authentication failed"

**Cause:** Federated identity credential not configured  
**Fix:** 
1. Verify Terraform applied successfully
2. Check Azure Portal → Azure AD → App Registrations → [your app] → Federated credentials
3. Verify subject claim matches: `repo:org/repo:environment:*`

---

### ❌ "ACR access denied"

**Cause:** RBAC role assignment missing or not propagated  
**Fix:**
1. Wait 5-10 minutes for RBAC propagation
2. Verify role assignment in Azure Portal: ACR → Access Control (IAM)
3. Ensure service principal has `AcrPush` role

---

### ❌ "Key Vault access denied"

**Cause:** RBAC role assignment missing  
**Fix:**
1. Verify Key Vault uses RBAC authorization (not access policies)
2. Check role assignment: Key Vault → Access Control (IAM)
3. Ensure service principal has `Key Vault Secrets User` role

## Detailed Activation Guide

For comprehensive step-by-step instructions, see:
- **[azure-activation.md](./azure-activation.md)** - Detailed activation process
- **[infra/README.md](../infra/README.md)** - Infrastructure documentation

## Deactivation

To deactivate the platform (tear down Azure resources):

```bash
cd infra/terraform
terraform destroy  # Type 'yes' to confirm
```

Then remove GitHub secrets from repository settings.

---

## Support

**Platform Status:** Fully implemented, activation-ready  
**Documentation:** Complete  
**Azure Costs:** ~$5-10/month (ACR + Key Vault)  
**Security Model:** OIDC federation (zero static credentials)

The platform is designed to activate with zero code changes after providing Azure credentials.
