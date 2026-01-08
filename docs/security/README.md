# CI/CD Security

## Purpose

This folder defines **how security is enforced** in the CI/CD platform.

Security is not optional. It is architectural.

## Core Security Principle

**CI/CD pipelines are first-class identities.**

Pipelines authenticate using **identity**, not secrets.

## Security Model

### Identity-Based Authentication

- Pipelines authenticate to cloud resources using **OpenID Connect (OIDC)**
- Trust is established between GitHub Actions and Azure Active Directory
- No long-lived credentials are stored or managed
- Authentication tokens are short-lived and scoped to minimum required permissions

### Secret Management

- Secrets are consumed at runtime, never stored in CI/CD
- Azure Key Vault is the single source of truth for secrets
- Pipelines retrieve secrets using identity-based authentication
- Secret rotation is automated and does not require pipeline changes

### Zero Trust Enforcement

Security controls are **enforced by the platform**, not requested from application teams.

Application teams cannot:
- Bypass identity-based authentication
- Store static credentials in repositories
- Use shared service principals
- Access production secrets outside the pipeline

## Security Documents

### [Identity and Authentication](./identity-and-authentication.md)

Defines:
- Pipeline identity model
- OIDC authentication flow
- Trust establishment between GitHub and Azure
- Explicitly prohibited authentication methods

### [Secrets Management](./secrets-management.md)

Defines:
- What qualifies as a secret
- How secrets are stored and accessed
- Key Vault integration model
- Difference between secrets and configuration

## Enforcement

Security controls are **architectural**, not procedural.

The platform enforces:

- **No static credentials**: Pipeline fails if repository secrets are used for cloud authentication
- **OIDC-only authentication**: Cloud access requires federated identity, not API keys
- **Least privilege**: Pipeline identities have minimal permissions scoped to specific stages
- **Audit logging**: All authentication and secret access is logged and retained

Non-compliant pipelines are rejected before execution.

## Security Is Non-Negotiable

There are no exceptions to these security controls.

Requests to:
- Use static credentials "just this once"
- Share service principals across pipelines
- Store secrets in repository variables
- Bypass OIDC authentication

**...are denied by design.**

The platform does not support insecure authentication methods.
