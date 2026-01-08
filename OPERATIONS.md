# Platform Operations Guide

This guide covers day-to-day operation of the CI/CD platform. For activation instructions, see [ACTIVATION-CHECKLIST.md](./ACTIVATION-CHECKLIST.md).

## What This Platform Does

This is a **reusable CI/CD platform** for GitHub Actions that enforces enterprise-grade patterns for building, testing, and deploying applications to Azure.

**Capabilities:**
- Automated build, test, and security scanning for every commit
- Branch-based environment routing (feature → dev, main → staging, etc.)
- Promotion-based production deployments with manual gates
- OIDC-based Azure authentication (zero static credentials)
- Immutable artifact versioning with full traceability
- Built-in observability and audit trails

**Consumer Model:** Application teams consume this platform via a thin wrapper workflow. They provide service-specific inputs; the platform handles enforcement, orchestration, and security.

## What This Platform Does NOT Do

- **Application-specific logic:** Build commands, test scripts, deployment manifests belong in application repos
- **Infrastructure provisioning:** AKS clusters, databases, networking are managed separately
- **Secret storage:** Secrets live in Azure Key Vault, not in GitHub
- **Multi-cloud support:** Azure only (by design)
- **Manual deployments:** All deployments go through the CI/CD pipeline

## Automated vs Manual Operations

### Fully Automated
- Build and artifact creation (on every push)
- Test execution and validation
- Security scanning (CVE detection)
- Deployment to development and staging
- Artifact metadata generation
- OIDC token exchange with Azure

### Requires Manual Action
- Production deployments (manual approval required via GitHub environments)
- Azure infrastructure provisioning (Terraform apply)
- GitHub secret configuration (one-time setup)
- Platform updates (changes to reusable workflows)
- Incident response and rollbacks

## Troubleshooting Guide

### When a Pipeline Fails

**Location:** GitHub Actions → Select workflow run → View failed job

**Common Failures:**

#### 1. Azure Pre-Flight Validation Fails
**Symptom:** Job "Azure Pre-Flight Validation" fails with "Azure not activated"  
**Cause:** Azure infrastructure not provisioned or GitHub secrets not configured  
**Fix:** Follow [ACTIVATION-CHECKLIST.md](./ACTIVATION-CHECKLIST.md) to complete activation

#### 2. OIDC Authentication Fails
**Symptom:** `azure/login` action fails with authentication error  
**Cause:** Federated identity credential misconfigured or GitHub secrets incorrect  
**Fix:**
```bash
# Verify federated credential in Azure Portal
Azure AD → App Registrations → [your-app] → Federated credentials

# Verify subject claim matches:
repo:org/repo:environment:*

# Check GitHub secrets match Terraform outputs:
terraform output azure_client_id
```

#### 3. Build Job Fails
**Symptom:** "Build" job fails during artifact creation  
**Cause:** Application-specific build logic issue (not platform issue)  
**Fix:** Check application repository's build configuration

#### 4. Test Job Fails
**Symptom:** "Test" job fails  
**Cause:** Application tests failing (not platform issue)  
**Fix:** Review test output, fix failing tests in application code

#### 5. Security Scan Blocks Deployment
**Symptom:** "Scan" job fails with critical vulnerabilities  
**Cause:** Container image or dependencies have CVEs  
**Fix:** Update vulnerable dependencies, rebuild

### When a Deployment Fails

**Location:** GitHub Actions → Deployment job logs

**Common Issues:**

#### ACR Access Denied
**Symptom:** Cannot push to Azure Container Registry  
**Fix:**
```bash
# Verify ACR role assignment
az role assignment list --scope /subscriptions/.../acr-resource-id

# Ensure service principal has AcrPush role
# Wait 5-10 minutes for RBAC propagation if just created
```

#### Key Vault Access Denied
**Symptom:** Cannot read secrets from Key Vault  
**Fix:**
```bash
# Verify Key Vault role assignment
az role assignment list --scope /subscriptions/.../kv-resource-id

# Ensure service principal has "Key Vault Secrets User" role
# Verify Key Vault uses RBAC (not access policies)
```

#### Deployment to Environment Fails
**Symptom:** Deploy job fails during Kubernetes/Helm operations  
**Cause:** Infrastructure issue (AKS cluster, networking, etc.)  
**Fix:** Check infrastructure logs, verify cluster health

### When Promotion is Blocked

**Location:** Workflow run → Production deployment job

**Reasons:**

#### Missing GitHub Environment
**Symptom:** Production job doesn't run  
**Fix:** Create "production" environment in GitHub repo settings with required reviewers

#### Approval Not Granted
**Symptom:** Job waiting for approval  
**Fix:** Required reviewers must approve in GitHub Actions UI

#### Staging Not Verified
**Symptom:** Production job skipped  
**Fix:** Ensure artifact was deployed and verified in staging first

## How to Safely Pause the Platform

### Temporary Pause (Emergency)

**Disable all workflows:**
```yaml
# In each workflow file, add at the top:
on:
  workflow_dispatch:  # Manual trigger only
```

**Or:** Go to GitHub Settings → Actions → Disable Actions for this repository

### Selective Pause

**Disable specific environment:**
```yaml
# In cicd-platform.yml, add to deploy job:
deploy-production:
  if: false  # Temporarily disable production deployments
```

**Disable specific workflow:**
- Rename workflow file: `.github/workflows/pipeline.yml` → `.github/workflows/pipeline.yml.disabled`

### Resume Operations

1. Remove `if: false` conditions
2. Restore original `on:` triggers
3. Re-enable Actions in repository settings
4. Commit and push changes

## Monitoring & Observability

### Workflow Execution Metrics
- **Location:** GitHub Actions → Insights (if available)
- **Monitor:** Success rate, duration, failure patterns

### Azure Resource Health
```bash
# Check ACR status
az acr check-health --name <acr-name>

# Check Key Vault status
az keyvault show --name <kv-name> --query "properties.provisioningState"
```

### Audit Trail
- **GitHub:** Actions → Workflow runs (who triggered, when, what changed)
- **Azure:** Monitor → Activity Log (who accessed resources, when)

## Common Maintenance Tasks

### Update Platform (Reusable Workflow Changes)
1. Modify `.github/workflows/cicd-platform.yml`
2. Test changes in a feature branch
3. Review with platform team
4. Merge to main (affects all consumers immediately)

### Update Terraform Infrastructure
```bash
cd infra/terraform
terraform plan   # Review changes
terraform apply  # Apply updates
terraform output # Verify outputs unchanged
```

### Rotate Nothing (OIDC Advantage)
With OIDC federation, there are **no credentials to rotate**. Azure access tokens are:
- Issued automatically by GitHub
- Short-lived (minutes)
- Scoped to specific operations
- Never stored anywhere

## Emergency Contacts

**Platform Team:** [your-team-contact]  
**Azure Admin:** [azure-admin-contact]  
**Security Team:** [security-team-contact]

**Escalation Path:**
1. Check this guide and troubleshooting section
2. Review platform documentation in `docs/`
3. Contact platform team
4. Escalate to Azure admin if infrastructure issue

---

**Platform Status:** Operational (waiting for Azure activation)  
**Last Updated:** 2026-01-08  
**Documentation:** See `docs/` for architecture, security, and design details
