# ============================================================================
# DATA SOURCES
# ============================================================================

data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

# ============================================================================
# RESOURCE GROUP
# ============================================================================

resource "azurerm_resource_group" "cicd" {
  name     = var.resource_group_name
  location = var.azure_location
  tags     = var.tags
}

# ============================================================================
# AZURE AD APPLICATION FOR GITHUB ACTIONS
# ============================================================================

# Azure AD Application for GitHub Actions authentication
resource "azuread_application" "github_actions" {
  display_name = "${var.resource_prefix}-github-actions"
  owners       = [data.azuread_client_config.current.object_id]

  tags = [
    "CICD",
    "GitHubActions",
    "OIDC",
  ]
}

# Service Principal for the application
resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
  owners    = [data.azuread_client_config.current.object_id]

  tags = [
    "CICD",
    "GitHubActions",
  ]
}

# ============================================================================
# OIDC FEDERATION WITH GITHUB
# ============================================================================

# Federated identity credential for GitHub Actions
# This enables GitHub Actions to authenticate without static secrets
resource "azuread_application_federated_identity_credential" "github_actions" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-actions-federation"
  description    = "Federated credential for GitHub Actions OIDC authentication"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  
  # Subject pattern: repo:<org>/<repo>:environment:<env>
  # Use ref:refs/heads/<branch> for branch-based, or environment:<name> for environment-based
  subject = var.github_environment != "*" ? (
    "repo:${var.github_organization}/${var.github_repository}:environment:${var.github_environment}"
  ) : (
    "repo:${var.github_organization}/${var.github_repository}:ref:refs/heads/${var.github_branch}"
  )
}

# ============================================================================
# AZURE CONTAINER REGISTRY (ACR)
# ============================================================================

# Generate unique ACR name (must be globally unique, alphanumeric only)
resource "random_string" "acr_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Container Registry for storing Docker images
resource "azurerm_container_registry" "cicd" {
  name                = "${var.resource_prefix}acr${random_string.acr_suffix.result}"
  resource_group_name = azurerm_resource_group.cicd.name
  location            = azurerm_resource_group.cicd.location
  sku                 = var.acr_sku

  # CRITICAL: Admin user is disabled - access only via identity
  admin_enabled = false

  # Identity-based authentication enforced
  # No username/password credentials
  public_network_access_enabled = true # Set to false for production hardening

  tags = merge(
    var.tags,
    {
      Service = "ContainerRegistry"
      Access  = "Identity-Based-Only"
    }
  )
}

# Grant GitHub Actions identity AcrPush role (push and pull images)
resource "azurerm_role_assignment" "acr_push" {
  scope                = azurerm_container_registry.cicd.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# ============================================================================
# AZURE KEY VAULT
# ============================================================================

# Generate unique Key Vault name (must be globally unique)
resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Key Vault for secrets management
resource "azurerm_key_vault" "cicd" {
  name                = "${var.resource_prefix}-kv-${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.cicd.location
  resource_group_name = azurerm_resource_group.cicd.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.key_vault_sku

  # CRITICAL: Use RBAC for access control (not legacy access policies)
  enable_rbac_authorization = true

  # Security hardening
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # Set to true for production

  # Network rules can be added here for production hardening
  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow" # Change to "Deny" with explicit allow rules in production
  }

  tags = merge(
    var.tags,
    {
      Service          = "KeyVault"
      AuthModel        = "RBAC"
      AccessPolicies   = "Disabled"
    }
  )
}

# Grant GitHub Actions identity Key Vault Secrets User role (read secrets)
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = azurerm_key_vault.cicd.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# Grant current user Key Vault Administrator for initial setup
resource "azurerm_role_assignment" "kv_admin_current_user" {
  scope                = azurerm_key_vault.cicd.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ============================================================================
# MINIMAL RBAC ON RESOURCE GROUP
# ============================================================================

# GitHub Actions identity gets Contributor at RG level for basic operations
# Adjust scope/role based on actual needs
resource "azurerm_role_assignment" "rg_contributor" {
  scope                = azurerm_resource_group.cicd.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# ============================================================================
# RANDOM STRING PROVIDER
# ============================================================================

terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
