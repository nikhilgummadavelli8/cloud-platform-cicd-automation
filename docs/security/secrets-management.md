# Secrets Management

This document defines **how secrets are stored, accessed, and managed** in the CI/CD platform.

**Core principle: Secrets are consumed at runtime, never stored in CI/CD.**

---

## What Qualifies as a Secret

A **secret** is any sensitive information that, if exposed, could compromise security.

### Secrets Include

- **Passwords and passphrases**: Database passwords, admin credentials
- **API keys and tokens**: Third-party service API keys, access tokens
- **Certificates and private keys**: TLS certificates, SSH private keys, signing keys
- **Connection strings**: Database connection strings containing credentials
- **Encryption keys**: Keys used for encrypting data at rest or in transit
- **OAuth client secrets**: Secrets for OAuth applications (though OIDC eliminates most of these)

### Secrets Do Not Include

- **Public identifiers**: Azure Client IDs, Tenant IDs, Subscription IDs (not sensitive)
- **Resource names**: AKS cluster names, ACR registry names (publicly discoverable)
- **Configuration values**: Feature flags, timeout values, environment names (not sensitive)
- **Non-sensitive environment variables**: Log levels, region names, service endpoints (public)

**Guideline**: If exposure would allow unauthorized access, it is a secret.

---

## What Must Never Be Stored in GitHub

The following must **never** be committed to Git or stored in GitHub:

### ❌ Committed to Source Code

**Prohibited**:
- Hard-coded passwords, API keys, or tokens in application code
- Connection strings with embedded credentials in config files
- Private keys or certificates in repository files
- `.env` files containing secrets (even in `.gitignore`)

**Enforcement**: GitHub secret scanning detects committed secrets and alerts repository owners.

**Consequence**: Committed secrets are considered compromised and must be rotated immediately.

---

### ❌ Stored in GitHub Repository Secrets (for Cloud Authentication)

**Prohibited**:
- Azure service principal client secrets
- AWS access keys or secret access keys
- GCP service account keys

**Enforcement**: Pipeline fails if repository secrets are used for cloud authentication.

**Why**: Static credentials create rotation burden and leakage risk. **OIDC eliminates the need for these secrets entirely.**

---

### ❌ Stored in GitHub Actions Cache or Artifacts

**Prohibited**:
- Caching credentials for reuse across pipeline runs
- Uploading secrets as workflow artifacts
- Persisting credentials to workspace directories

**Enforcement**: Secrets are consumed within a single step and discarded immediately.

**Why**: Cached or persisted secrets create exfiltration risk beyond the pipeline execution scope.

---

## How Secrets Are Stored: Azure Key Vault

### Single Source of Truth

**Azure Key Vault** is the only approved secret storage system.

All secrets are stored in Key Vault and retrieved at runtime by pipelines using **identity-based authentication**.

### Key Vault Secret Types

Key Vault supports three types of secrets:

1. **Secrets**: Arbitrary key-value pairs (API keys, passwords, connection strings)
2. **Keys**: Cryptographic keys for encryption/decryption (used for data encryption)
3. **Certificates**: TLS certificates and private keys (used for HTTPS endpoints)

Pipelines access these using the Azure Key Vault action or SDK.

### Key Vault Access Model

Pipelines access Key Vault using **OIDC authentication** (not API keys).

```yaml
- name: Retrieve Secret from Key Vault
  uses: azure/get-keyvault-secrets@v1
  with:
    keyvault: my-keyvault
    secrets: 'database-password, api-key'
```

**No credentials required.** The pipeline's federated identity grants access to Key Vault.

---

## Secrets vs Configuration

Understanding the difference between secrets and configuration is critical.

| Aspect           | Secrets                              | Configuration                     |
|------------------|--------------------------------------|-----------------------------------|
| **Sensitivity**  | Sensitive (compromises security)     | Non-sensitive (public or low-risk) |
| **Storage**      | Azure Key Vault                      | Environment variables, config files |
| **Access**       | Identity-based (OIDC)                | Publicly readable or low-trust    |
| **Rotation**     | Automated rotation required          | No rotation needed                |
| **Example**      | Database password, API key           | Database hostname, timeout value  |

### When to Use Key Vault

Store in Key Vault if:
- Exposure would allow unauthorized access
- Value must be rotated periodically
- Access must be audited

### When to Use Configuration

Store as configuration (environment variables, GitHub variables) if:
- Value is publicly discoverable (e.g., Azure region)
- Value can be committed to source control without risk
- Access does not need to be audited

**If uncertain, default to Key Vault.** Over-protecting is safer than under-protecting.

---

## Identity vs Credentials

The platform distinguishes between **identity** (who you are) and **credentials** (proof of identity).

### Identity

**Identity** is a first-class principal that is trusted by the cloud provider.

Examples:
- Federated identity credential (GitHub → Azure via OIDC)
- Managed identity (Azure VM, AKS pod)
- User identity (Azure AD user)

**Identities do not require credentials.** Trust is established via federation or platform integration.

### Credentials

**Credentials** are secrets used to authenticate an identity.

Examples:
- Username and password
- Client secret for service principal
- API key for third-party service

**The platform eliminates credentials wherever possible** by using identity-based authentication (OIDC, managed identities).

### Pipeline Authentication: Identity, Not Credentials

Pipelines authenticate using **federated identity** (OIDC), not credentials.

- ❌ **Old model**: Pipeline uses client secret (credential) to authenticate
- ✅ **New model**: Pipeline uses federated identity (no credential required)

**Result**: No secrets to store, rotate, or leak.

---

## Secret Lifecycle Management

### Secret Creation

Secrets are created and stored in Key Vault by:
- **Platform team**: For infrastructure-level secrets (service endpoints, platform API keys)
- **Application team**: For application-specific secrets (database passwords, third-party API keys)

Secrets are created via:
- Azure CLI: `az keyvault secret set`
- Azure portal
- Terraform (for infrastructure-as-code)

**Secrets are never created in pipelines.** Pipelines consume secrets, they do not create them.

### Secret Rotation

Secrets must be rotated periodically to limit exposure window.

**Automated rotation** (preferred):
- Key Vault supports auto-rotation for some secrets (e.g., storage account keys)
- Azure AD can auto-rotate service principal credentials (though OIDC eliminates this need)

**Manual rotation** (when required):
- Platform team updates secret in Key Vault
- Pipelines automatically retrieve new secret on next run (no pipeline changes required)

**Rotation does not require pipeline updates** because secrets are retrieved at runtime, not hard-coded.

### Secret Expiration

All secrets have an expiration date.

- **Default expiration**: 1 year (configurable per secret)
- **Grace period**: 30 days before expiration, alerts are sent to secret owner
- **Hard expiration**: After expiration, secret is disabled and must be rotated

**Pipelines fail if attempting to use expired secrets.** This forces rotation.

### Secret Deletion

Secrets are soft-deleted in Key Vault (recoverable for 90 days) and then permanently purged.

**Pipelines fail if attempting to access deleted secrets.** Secret deletion is intentional and requires re-creation.

---

## Secrets in CI/CD: Runtime Consumption Only

### How Secrets Are Consumed

Secrets are retrieved **at runtime** within a specific pipeline step:

```yaml
- name: Deploy Application
  run: |
    # Retrieve secret from Key Vault
    DB_PASSWORD=$(az keyvault secret show --vault-name my-vault --name db-password --query value -o tsv)
    
    # Use secret in deployment
    helm upgrade my-app ./chart --set database.password=$DB_PASSWORD
  env:
    # No secrets in environment variables (retrieved at runtime)
```

**Secrets are never persisted** to:
- File system
- Environment variables (across steps)
- Workflow cache
- Artifacts

**Secrets exist only in memory** during the step that retrieves them.

### Secret Masking

GitHub Actions automatically masks secrets in logs:
- If a secret value appears in logs, it is replaced with `***`
- This prevents accidental exposure in build logs

**Do not rely on masking alone.** Secrets should not be logged in the first place.

---

## GitHub Secrets: Permitted Use Cases

GitHub repository secrets are permitted **only** for non-cloud authentication use cases.

### ✅ Permitted: Application-Specific Secrets

GitHub secrets may be used for:
- **Third-party API keys**: SaaS services that do not support OIDC (e.g., Datadog API key)
- **Notification webhooks**: Slack webhook URLs, PagerDuty integration keys
- **Code signing certificates**: Secrets for signing artifacts (not available in Key Vault)

**These secrets are consumed by pipelines, not used for cloud authentication.**

### ❌ Prohibited: Cloud Authentication Secrets

GitHub secrets must **not** be used for:
- Azure service principal client secrets
- AWS access keys
- GCP service account keys

**Cloud authentication uses OIDC exclusively.**

### Secret Scoping in GitHub

GitHub secrets can be scoped to:
- **Repository secrets**: Available to all workflows in the repository
- **Environment secrets**: Available only to workflows deploying to a specific environment (dev, staging, production)

**Production secrets must be environment-scoped** to prevent accidental exposure in dev/staging.

---

## Key Vault Integration Model

### Key Vault per Environment

Each environment has a dedicated Key Vault:
- **Dev Key Vault**: Secrets for development environment
- **Staging Key Vault**: Secrets for staging environment
- **Production Key Vault**: Secrets for production environment

**No shared Key Vaults.** Each environment is isolated.

### Pipeline Access to Key Vault

Pipelines access Key Vault using **federated identity** (OIDC).

Azure RBAC roles grant pipelines access:
- **Dev pipeline**: `Key Vault Secrets User` on dev Key Vault
- **Staging pipeline**: `Key Vault Secrets User` on staging Key Vault
- **Production pipeline**: `Key Vault Secrets User` on production Key Vault

**Production pipelines cannot access dev/staging Key Vaults** (and vice versa).

### Secret Naming Convention

Secrets follow a consistent naming pattern:

```
<service>-<secret-type>-<environment>
```

Examples:
- `postgres-password-dev`
- `api-gateway-tls-cert-prod`
- `redis-connection-string-staging`

Consistent naming simplifies automation and auditing.

---

## Audit and Compliance

### Secret Access Logging

All secret access is logged:
- **Key Vault access logs**: Who accessed which secret, when
- **Azure AD sign-in logs**: Which pipeline identity was used
- **GitHub Actions logs**: Which workflow retrieved secrets

**Retention**: Secret access logs retained for 2 years (compliance requirement).

### Compliance Requirements

Secrets management must comply with:
- **SOC 2**: Secrets must be encrypted at rest and in transit
- **PCI-DSS**: Cardholder data secrets must be rotated quarterly
- **GDPR**: Secrets containing personal data must be protected and auditable

Key Vault and OIDC authentication satisfy these requirements by design.

---

## Exception Process

### No Exceptions for Static Credentials in Cloud Auth

There is **no exception process** for storing Azure credentials in GitHub repository secrets.

All cloud authentication uses OIDC. No alternatives are supported.

### Exceptions for Non-Cloud Secrets

For third-party services that do not support OIDC (e.g., legacy SaaS APIs):

1. Application team requests exception with justification
2. Security team reviews and approves (or denies)
3. If approved, secret is stored in GitHub environment secrets (scoped to production)
4. Secret rotation plan is documented and enforced

**Exception is time-limited** and must be re-justified annually.

---

## Conformance

This secrets management model is **mandatory** and **non-negotiable**.

Pipelines that:
- Store secrets in source code
- Use static credentials for cloud authentication
- Bypass Key Vault for secret storage

**...will fail validation and be rejected.**

The platform enforces secrets management architecturally.
