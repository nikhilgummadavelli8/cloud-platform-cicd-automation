# ============================================================================
# OUTPUTS FOR GITHUB ACTIONS INTEGRATION
# ============================================================================

# Azure AD / Identity Outputs
output "azure_client_id" {
  description = "Client ID of the Azure AD application for GitHub Actions OIDC"
  value       = azuread_application.github_actions.client_id
}

output "azure_tenant_id" {
  description = "Azure AD tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "azure_subscription_id" {
  description = "Azure subscription ID"
  value       = data.azurerm_client_config.current.subscription_id
}

# Container Registry Outputs
output "acr_login_server" {
  description = "Login server URL for Azure Container Registry"
  value       = azurerm_container_registry.cicd.login_server
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.cicd.name
}

output "acr_id" {
  description = "Resource ID of the Azure Container Registry"
  value       = azurerm_container_registry.cicd.id
}

# Key Vault Outputs
output "key_vault_name" {
  description = "Name of the Azure Key Vault"
  value       = azurerm_key_vault.cicd.name
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault"
  value       = azurerm_key_vault.cicd.vault_uri
}

output "key_vault_id" {
  description = "Resource ID of the Azure Key Vault"
  value       = azurerm_key_vault.cicd.id
}

# Resource Group Outputs
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.cicd.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.cicd.location
}

# ============================================================================
# GITHUB ACTIONS CONFIGURATION REFERENCE
# ============================================================================

output "github_actions_oidc_config" {
  description = "Configuration values needed for GitHub Actions workflows"
  value = {
    client_id       = azuread_application.github_actions.client_id
    tenant_id       = data.azurerm_client_config.current.tenant_id
    subscription_id = data.azurerm_client_config.current.subscription_id
    acr_login_server = azurerm_container_registry.cicd.login_server
    key_vault_name   = azurerm_key_vault.cicd.name
  }
  sensitive = false
}

# ============================================================================
# EXAMPLE GITHUB ACTIONS WORKFLOW SNIPPET
# ============================================================================

output "example_github_workflow_snippet" {
  description = "Example snippet for GitHub Actions workflow using OIDC"
  value = <<-EOT
    # Add these secrets/variables to your GitHub repository:
    # - AZURE_CLIENT_ID: ${azuread_application.github_actions.client_id}
    # - AZURE_TENANT_ID: ${data.azurerm_client_config.current.tenant_id}
    # - AZURE_SUBSCRIPTION_ID: ${data.azurerm_client_config.current.subscription_id}
    
    # Example workflow job:
    jobs:
      build:
        runs-on: ubuntu-latest
        permissions:
          id-token: write  # Required for OIDC
          contents: read
        steps:
          - uses: azure/login@v1
            with:
              client-id: $${{ secrets.AZURE_CLIENT_ID }}
              tenant-id: $${{ secrets.AZURE_TENANT_ID }}
              subscription-id: $${{ secrets.AZURE_SUBSCRIPTION_ID }}
          
          - name: Login to ACR
            run: az acr login --name ${azurerm_container_registry.cicd.name}
          
          - name: Get Key Vault secret
            uses: azure/get-keyvault-secrets@v1
            with:
              keyvault: ${azurerm_key_vault.cicd.name}
              secrets: 'your-secret-name'
  EOT
}
