# ============================================================================
# AZURE CONFIGURATION
# ============================================================================

variable "azure_subscription_id" {
  description = "Azure subscription ID where resources will be created"
  type        = string
  # Set via environment variable: export TF_VAR_azure_subscription_id="your-subscription-id"
}

variable "azure_location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "eastus"

  validation {
    condition     = can(regex("^[a-z]+[0-9]?$", var.azure_location))
    error_message = "Location must be a valid Azure region (e.g., eastus, westus2)."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group (will be created if it doesn't exist)"
  type        = string
  default     = "cicd-platform-rg"
}

# ============================================================================
# GITHUB OIDC CONFIGURATION
# ============================================================================

variable "github_organization" {
  description = "GitHub organization or username"
  type        = string
  default     = "nikhilgummadavelli8"
}

variable "github_repository" {
  description = "GitHub repository name (without org prefix)"
  type        = string
  default     = "cloud-platform-cicd-automation"
}

variable "github_branch" {
  description = "GitHub branch allowed to authenticate (use '*' for any branch)"
  type        = string
  default     = "main"
}

variable "github_environment" {
  description = "GitHub environment name for OIDC (use '*' for any environment, or specific like 'production')"
  type        = string
  default     = "*"
}

# ============================================================================
# RESOURCE NAMING
# ============================================================================

variable "resource_prefix" {
  description = "Prefix for all resource names to ensure uniqueness"
  type        = string
  default     = "cicdplatform"

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.resource_prefix))
    error_message = "Prefix must be 3-10 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# ============================================================================
# CONTAINER REGISTRY
# ============================================================================

variable "acr_sku" {
  description = "Azure Container Registry SKU (Basic, Standard, Premium)"
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

# ============================================================================
# KEY VAULT
# ============================================================================

variable "key_vault_sku" {
  description = "Key Vault SKU (standard or premium)"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku)
    error_message = "Key Vault SKU must be standard or premium."
  }
}

# ============================================================================
# TAGS
# ============================================================================

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "CICD-Platform"
    ManagedBy   = "Terraform"
    Purpose     = "GitHub Actions CI/CD Infrastructure"
    CostCenter  = "Engineering"
  }
}
