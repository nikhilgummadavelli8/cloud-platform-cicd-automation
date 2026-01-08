# Identity and Authentication

This document defines **how pipelines authenticate to cloud resources**.

Static credentials are architecturally impossible under this model.

## Pipeline Identity Model

### Pipelines as First-Class Identities

Every pipeline execution has a distinct identity established through **OpenID Connect (OIDC)**.

Pipeline identity is determined by:
- **Repository**: Which GitHub repository the workflow belongs to
- **Branch**: Which branch triggered the workflow
- **Environment**: Which GitHub environment the job is deploying to (dev, staging, production)
- **Workflow**: Which workflow file is executing

**No shared identities.** Each pipeline has a unique identity based on these attributes.

### Identity Hierarchy

```
GitHub Organization
  └── Repository
       └── Workflow File
            └── Environment
                 └── Pipeline Identity (OIDC Subject Claim)
```

Azure AD trusts the pipeline identity based on the **OIDC subject claim**, which encodes:
- Repository name
- Branch or environment
- Workflow path

Example subject claim:
```
repo:nikhilgummadavelli8/cloud-platform-cicd-automation:environment:production
```

Azure AD validates this claim and issues a short-lived access token scoped to production permissions.

---

## OIDC-Based Authentication

### Authentication Flow

The authentication flow is **entirely identity-based**. No secrets are involved.

#### Step 1: Pipeline Requests Token from GitHub

The pipeline uses the `actions/github-token` or Azure login action to request an OIDC token:

```yaml
- name: Authenticate to Azure
  uses: azure/login@v1
  with:
    client-id: ${{ vars.AZURE_CLIENT_ID }}        # Not a secret (public identifier)
    tenant-id: ${{ vars.AZURE_TENANT_ID }}        # Not a secret (public identifier)
    subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}  # Not a secret (public identifier)
```

**No secrets in this step.** Client ID, tenant ID, and subscription ID are **not secrets**—they are public identifiers.

#### Step 2: GitHub Issues OIDC Token

GitHub Actions generates a **short-lived OIDC token** (JWT) containing:
- Repository identity
- Workflow identity
- Environment (if applicable)
- Expiration time (typically 1 hour)

The token is signed by GitHub's private key.

#### Step 3: Pipeline Presents Token to Azure

The pipeline sends the OIDC token to Azure AD's token endpoint.

Azure validates:
- **Issuer**: Token was issued by GitHub (verifies signature)
- **Audience**: Token is intended for Azure (`aud` claim)
- **Subject**: Token identifies an authorized repository/environment (`sub` claim)
- **Expiration**: Token is not expired (`exp` claim)

#### Step 4: Azure Issues Access Token

If validation succeeds, Azure AD issues a **short-lived access token** with permissions scoped to:
- The specific Azure subscription
- The specific resource group (if constrained)
- The specific Azure resources (AKS, ACR, Key Vault)

The access token expires automatically (typically 1 hour).

#### Step 5: Pipeline Uses Access Token

The pipeline uses the access token to authenticate to Azure resources:
- Deploy to AKS
- Push container images to ACR
- Retrieve secrets from Key Vault

**Token expires automatically.** No cleanup or rotation required.

---

## Trust Establishment

### Federated Identity Credential (Azure AD)

Azure AD is configured with a **Federated Identity Credential** that establishes trust with GitHub.

The credential defines:
- **Issuer**: `https://token.actions.githubusercontent.com`
- **Subject**: Repository and environment pattern (e.g., `repo:org/repo:environment:production`)
- **Audience**: `api://AzureADTokenExchange`

**This configuration is done once** during platform setup. Pipelines do not manage trust.

### No Shared Secrets

Traditional authentication (service principals with client secrets) requires:
- Storing client secret in GitHub repository secrets
- Rotating secrets manually
- Managing secret expiration
- Risk of secret leakage

**OIDC eliminates all of this.** Trust is established via federation, not shared secrets.

---

## Permissions and Scoping

### Least Privilege by Default

Pipeline identities are granted **minimal permissions** required for their specific stage.

| Stage  | Azure RBAC Role          | Scope               |
|--------|--------------------------|---------------------|
| Build  | AcrPush                  | Container Registry  |
| Deploy | AKS Contributor          | AKS Cluster         |
| Verify | Reader                   | Resource Group      |

**No pipeline has broad permissions.** Each stage uses a distinct identity with scoped access.

### Environment-Specific Permissions

Production identities have additional constraints:
- **Time-based access**: Production deployments allowed only during approved hours
- **Conditional access**: MFA required for production approval (human approvers)
- **Break-glass access**: Emergency access logged and audited

---

## Explicitly Prohibited Authentication Methods

The following authentication methods are **prohibited** and prevented by platform enforcement:

### ❌ Static Secrets in Repository

**Prohibited**:
- Storing Azure service principal secrets in GitHub repository secrets
- Storing API keys, passwords, or connection strings in repository variables
- Committing credentials to source code

**Enforcement**: Pipeline fails if repository secrets are referenced for cloud authentication.

**Why prohibited**: Static secrets create rotation burden, leakage risk, and audit gaps.

---

### ❌ Long-Lived Service Principals

**Prohibited**:
- Using service principals with passwords or client secrets
- Sharing service principals across multiple pipelines
- Manually rotating credentials

**Enforcement**: Platform does not support client secret authentication; only federated identity credentials.

**Why prohibited**: Long-lived credentials increase blast radius of compromise and require manual rotation.

---

### ❌ Shared Credentials Across Pipelines

**Prohibited**:
- Multiple repositories using the same Azure identity
- Sharing credentials between dev and production environments
- Using a single "CI/CD service account" for all pipelines

**Enforcement**: Each pipeline has a unique federated identity credential scoped to its repository and environment.

**Why prohibited**: Shared credentials make compromise containment impossible and violate least privilege.

---

### ❌ Credential Storage in CI/CD

**Prohibited**:
- Storing secrets in GitHub Actions cache
- Persisting credentials to workspace or artifacts
- Logging credentials in pipeline output

**Enforcement**: Credentials are consumed within a single step and not persisted.

**Why prohibited**: Stored credentials create exfiltration risk and violate secret lifecycle management.

---

## Authentication Validation

### Pipeline Startup Checks

Every pipeline execution validates:

1. **OIDC token issuance**: GitHub successfully issued a valid token
2. **Azure trust validation**: Azure AD accepted the federated credential
3. **Access token scoping**: Token permissions match expected RBAC role
4. **Token expiration**: Token is valid for the expected duration

If any validation fails, the pipeline terminates immediately.

### Audit Logging

All authentication events are logged:
- **GitHub OIDC token requests**: Logged by GitHub Actions
- **Azure AD token exchanges**: Logged in Azure AD sign-in logs
- **Resource access**: Logged in Azure Activity Logs

**Retention**: Authentication logs retained for 2 years (compliance requirement).

---

## Exception Process

### No Exceptions for Static Credentials

There is **no exception process** for using static credentials.

Requests to:
- Store service principal secrets in repository
- Use API keys for cloud authentication
- Bypass OIDC authentication

**...are denied.**

The platform does not and will not support static credential authentication.

### Alternative: Managed Identities for Non-Pipeline Access

For operations that cannot use OIDC (e.g., local development, debugging):

- **Local development**: Use Azure CLI with user authentication (`az login`)
- **Debugging**: Use Azure portal or Cloud Shell with user credentials
- **Automation outside CI/CD**: Use Azure Managed Identities (VM/container-based)

**CI/CD pipelines use OIDC exclusively.**

---

## Implementation Status

### Current State (Post-Foundation)

- ✅ Identity model documented
- ✅ OIDC authentication flow defined
- ✅ Static credentials explicitly prohibited
- ⏳ Enforcement hooks in pipeline skeleton (placeholders)

### Next Steps

- **Azure AD Configuration**: Create federated identity credentials for dev, staging, production
- **Pipeline Implementation**: Replace OIDC placeholders with actual `azure/login` action
- **RBAC Setup**: Assign least-privilege roles to pipeline identities
- **Validation**: Test authentication flow in live environment

OIDC authentication will be functional after Azure AD is configured.

---

## Conformance

This identity model is **mandatory** and **non-negotiable**.

Pipelines that attempt to:
- Use static credentials
- Bypass OIDC authentication
- Share identities across environments

**...will fail validation and be rejected.**

The platform enforces identity-based authentication architecturally.
