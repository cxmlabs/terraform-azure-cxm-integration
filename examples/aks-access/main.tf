# ==============================================================================
# AKS Access Example
# ==============================================================================
#
# This example installs the CXM integration and gives its Service Principal
# read access to the Kubernetes API of the AKS clusters of the subscription,
# in one configuration. The clusters must use Entra ID and Azure RBAC.
#
# ==============================================================================

provider "azurerm" {
  features {}
}

provider "azuread" {}

module "cxm_integration" {
  source = "../../"

  # Storage accounts for cost and activity data (must already exist)
  billing_export_storage_account_name   = "mycompanycostexports"
  billing_export_storage_resource_group = "finops-rg"
  billing_export_focus_path             = "az://cost-exports/daily/cxm-daily-export-focus/**/*.parquet"

  activity_log_storage_account_name   = "mycompanyactivitylogs"
  activity_log_storage_resource_group = "logging-rg"

  # Create the CXM AKS Reader role and assign it on each subscription
  enable_aks_access = true
}

# ==============================================================================
# Outputs - Provide these to CXM
# ==============================================================================

output "cxm_onboarding_values" {
  description = "Values to provide to CXM during onboarding"
  value       = module.cxm_integration.cxm_onboarding_values
  sensitive   = true
}

output "features_enabled" {
  description = "Summary of enabled features"
  value       = module.cxm_integration.features_enabled
}
