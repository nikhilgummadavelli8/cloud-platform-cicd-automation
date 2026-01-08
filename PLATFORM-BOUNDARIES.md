# Platform Boundaries

This document defines what changes are **allowed**, **restricted**, and **forbidden** in this CI/CD platform. These boundaries prevent platform erosion and ensure consistency across all consuming applications.

## Purpose

Without explicit boundaries:
- Application teams bypass security controls
- Platform guarantees become optional
- Enforcement erodes over time
- "Just this once" becomes permanent

These boundaries are **non-negotiable** and exist to protect both the platform and its consumers.

---

## ✅ Allowed Changes (No Approval Needed)

These changes can be made by application teams in their own repositories **without platform team involvement**:

### 1. Service-Specific Inputs
Application teams control their own workflow wrapper inputs:

```yaml
# .github/workflows/my-app-pipeline.yml (Application Repo)
jobs:
  platform-cicd:
    uses: org/platform-repo/.github/workflows/cicd-platform.yml@main
    with:
      service_name: "my-service"           # ✅ Allowed
      artifact_type: "container-image"     # ✅ Allowed
      deploy_enabled: true                 # ✅ Allowed
      run_tests: true                      # ✅ Allowed
      run_security_scan: true              # ✅ Allowed
      environment: "auto"                  # ✅ Allowed
```

### 2. Application Build Logic
How to build, test, and package the application:

- Dockerfile content
- Build scripts and commands
- Test frameworks and configurations
- Dependency management (package.json, requirements.txt, etc.)
- Application code and configuration

**Boundary:** Application teams own the "what to build". Platform owns the "how to ensure it's built safely".

### 3. Deployment Manifests
Application-specific deployment configuration:

- Kubernetes manifests
- Helm charts
- Environment-specific configuration (dev, staging, prod)
- Resource limits and scaling policies

**Boundary:** Application teams define what gets deployed. Platform enforces how and when.

### 4. Workflow Triggers
When the pipeline runs:

```yaml
on:
  push:
    branches: [main, 'feature/**']  # ✅ Allowed
  pull_request:                      # ✅ Allowed
  schedule:                          # ✅ Allowed
    - cron: '0 2 * * *'
```

### 5. GitHub Environment Configuration
Creating and configuring GitHub environments (dev, staging, production):

- Environment-specific secrets
- Environment protection rules
- Required reviewers for production
- Deployment branch policies

**Boundary:** Teams can create environments, but reusable workflow enforcement still applies.

---

## ⚠️ Restricted Changes (Platform Approval Required)

These changes affect the platform or multiple teams. **Require platform team review and approval** before implementation:

### 1. Reusable Workflow Modifications
Any changes to `.github/workflows/cicd-platform.yml`:

- Adding new jobs or stages
- Modifying enforcement logic
- Changing artifact versioning schemes
- Updating security scanning tools
- Altering promotion gates

**Why Restricted:** Changes affect all consuming applications immediately. Must be tested thoroughly.

**Approval Process:**
1. Open PR with detailed explanation
2. Platform team reviews impact
3. Test with pilot applications
4. Merge after approval

### 2. Promotion Logic Changes
Modifications to branch → environment mapping:

```yaml
# Changing this requires platform approval:
if [[ "$BRANCH" == "main" ]]; then
  DEPLOY_STAGING="true"  # Current logic
fi
```

**Why Restricted:** Promotion model is a platform guarantee. Changing it affects compliance and security posture.

### 3. Security Enforcement Updates
Changes to security controls:

- OIDC authentication requirements
- Secret scanning configuration
- Vulnerability thresholds
- Compliance checks

**Why Restricted:** Security controls protect the entire organization.

### 4. Artifact Handling Changes
Modifications to artifact creation, storage, or metadata:

- Tagging strategies
- Immutability rules
- Metadata schemas
- Registry configuration

**Why Restricted:** Artifact traceability is a platform guarantee.

---

## 🚫 Forbidden Changes (Never Allowed)

These changes are **explicitly disallowed** because they violate platform security or integrity guarantees:

### 1. Disabling OIDC Authentication

```yaml
# ❌ FORBIDDEN
- uses: azure/login@v1
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}  # Static credentials
```

```yaml
# ✅ REQUIRED
- uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

**Why Forbidden:** OIDC is a core security control. Static credentials create credential leakage risks.

### 2. Skipping Security Verification

```yaml
# ❌ FORBIDDEN
run_security_scan: false  # Bypassing security scan
```

```yaml
# ❌ FORBIDDEN
if: false  # Disabling scan job in reusable workflow
```

**Why Forbidden:** Security scanning is mandatory for all deployments.

### 3. Bypassing Promotion Gates

```yaml
# ❌ FORBIDDEN - Deploying to production without staging
deploy-production:
  needs: [build]  # Skipping staging verification
```

```yaml
# ✅ REQUIRED
deploy-production:
  needs: [build, test, scan, deploy-staging]  # Proper promotion
```

**Why Forbidden:** Production must only receive artifacts verified in staging.

### 4. Rebuilding Artifacts for Production

```yaml
# ❌ FORBIDDEN - Building fresh artifact in production deploy
- name: Build for Production
  run: docker build -t myapp:prod .
```

```yaml
# ✅ REQUIRED - Using existing immutable artifact
- name: Deploy to Production
  run: |
    IMAGE="${{ needs.build.outputs.artifact_registry }}/myapp:${{ needs.build.outputs.image_tag }}"
    kubectl set image deployment/myapp myapp=$IMAGE
```

**Why Forbidden:** Violates "build once, deploy everywhere". What's tested in staging must be identical to production.

### 5. Using Mutable Tags

```yaml
# ❌ FORBIDDEN
image_tag: "latest"      # Mutable
image_tag: "prod"        # Mutable
image_tag: "main"        # Mutable
```

```yaml
# ✅ REQUIRED
image_tag: "7a3f9c2"     # Immutable (commit SHA)
image_tag: "v1.2.3"      # Immutable (semantic version)
```

**Why Forbidden:** Mutable tags break traceability and artifact immutability.

### 6. Hardcoding Secrets in Code

```yaml
# ❌ FORBIDDEN
env:
  API_KEY: "sk-abc123..."  # Hardcoded secret
```

```yaml
# ✅ REQUIRED
- uses: azure/get-keyvault-secrets@v1
  with:
    keyvault: ${{ secrets.KEY_VAULT_NAME }}
    secrets: 'api-key'
```

**Why Forbidden:** Secrets must live in Azure Key Vault, retrieved at runtime via OIDC.

### 7. Disabling Deployment Gates

```yaml
# ❌ FORBIDDEN - Removing manual approval for production
environment:
  name: production
  # No protection rules
```

```yaml
# ✅ REQUIRED
environment:
  name: production
  # Protected with required reviewers in GitHub UI
```

**Why Forbidden:** Production deployments require human approval.

---

## Enforcement

### How Boundaries Are Enforced

**Allowed Changes:**
- Application-level controls (no enforcement needed)
- Teams have full autonomy

**Restricted Changes:**
- PR review by platform team
- Automated tests in platform repo
- Pilot testing before merge

**Forbidden Changes:**
- Reusable workflow logic prevents bypass
- OIDC permissions enforced by Azure AD
- Immutability enforced by registry configuration
- PR reviews will reject violations

### Violation Response

If a forbidden change is attempted:

1. **Reject immediately** in PR review
2. **Explain why** it's forbidden (link to this document)
3. **Offer alternative** that achieves the goal within boundaries
4. **Escalate to security team** if pattern repeats

### Requesting Boundary Changes

If a boundary prevents legitimate work:

1. Open GitHub Discussion: "Platform Boundary Exception Request"
2. Explain the use case and why current boundaries don't work
3. Platform team evaluates if boundary should be adjusted
4. If approved, update this document first, then implement change

**Do not:** Work around boundaries without approval.

---

## Rationale

These boundaries exist because:

- **Security:** OIDC, secrets management, and supply chain integrity are non-negotiable
- **Consistency:** All teams deploy the same way (predictable, auditable)
- **Maintainability:** Platform can evolve without breaking consumers
- **Compliance:** Audit requirements mandate certain controls
- **Safety:** Production is protected by design, not by hope

---

**Platform Philosophy:** Be generous with autonomy, strict with safety.

**Last Updated:** 2026-01-08  
**Owner:** Platform Team  
**Review Cadence:** Quarterly
