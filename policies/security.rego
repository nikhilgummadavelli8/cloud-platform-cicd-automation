package security

# Security Policy: Enforce OIDC authentication and prohibit static credentials
# This policy validates that workflows use OpenID Connect (OIDC) for cloud authentication
# and do not rely on static secrets like service principal passwords.

# SECURITY REQUIREMENTS (from docs/security/identity-and-authentication.md):
# 1. All cloud authentication must use OIDC (id-token: write permission)
# 2. No static credentials (AZURE_CLIENT_SECRET, AZURE_PASSWORD, etc.)
# 3. Azure login must use OIDC pattern (client-id, tenant-id, subscription-id)
# 4. No hardcoded secrets in workflow files

# Prohibited secret names (static credentials)
prohibited_secrets := {
    "AZURE_CLIENT_SECRET",
    "AZURE_PASSWORD",
    "AZURE_CREDENTIALS",
    "SERVICE_PRINCIPAL_SECRET",
    "CLIENT_SECRET"
}

# Check if workflow uses OIDC (has id-token: write permission)
uses_oidc {
    input.permissions["id-token"] == "write"
}

uses_oidc {
    input.jobs[_].permissions["id-token"] == "write"
}

# Check if workflow uses Azure login action
uses_azure_login {
    input.jobs[_].steps[_].uses
    contains(input.jobs[_].steps[_].uses, "azure/login@")
}

# Check if Azure login uses OIDC pattern (has client-id, tenant-id, subscription-id)
azure_login_uses_oidc {
    step := input.jobs[_].steps[_]
    contains(step.uses, "azure/login@")
    step.with["client-id"]
    step.with["tenant-id"]
    step.with["subscription-id"]
    # Must NOT have client-secret
    not step.with["client-secret"]
}

# Check for prohibited secrets usage
uses_prohibited_secret[secret_name] {
    secret_name := prohibited_secrets[_]
    input.jobs[_].steps[_].env[_]
    contains(input.jobs[_].steps[_].env[_], secret_name)
}

uses_prohibited_secret[secret_name] {
    secret_name := prohibited_secrets[_]
    input.jobs[_].steps[_].with[_]
    contains(input.jobs[_].steps[_].with[_], secret_name)
}

uses_prohibited_secret[secret_name] {
    secret_name := prohibited_secrets[_]
    input.env[_]
    contains(input.env[_], secret_name)
}

# DENY: Azure login without OIDC
deny[msg] {
    uses_azure_login
    not azure_login_uses_oidc
    msg := "POLICY VIOLATION: Azure login must use OIDC authentication (client-id, tenant-id, subscription-id). Static credentials (client-secret) are prohibited."
}

# DENY: Uses prohibited static secrets
deny[msg] {
    secret := uses_prohibited_secret[_]
    msg := sprintf("POLICY VIOLATION: Prohibited secret '%s' detected. Use OIDC authentication instead of static credentials.", [secret])
}

# WARN: No OIDC permission set (may be intentional for non-cloud workflows)
warn[msg] {
    not uses_oidc
    not uses_azure_login
    msg := "INFO: No OIDC authentication detected. This is OK for workflows that don't access cloud resources."
}

# WARN: OIDC enabled but no Azure login
warn[msg] {
    uses_oidc
    not uses_azure_login
    msg := "INFO: OIDC permission set but no Azure login action found. Verify cloud authentication is configured."
}

# SUCCESS: All security checks pass
allow {
    count(deny) == 0
}
