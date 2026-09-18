# ==============================================================================
# Basic Example - Single Subscription
# ==============================================================================
#
# This example deploys the CXM integration to a single subscription using
# client secret authentication. This is the simplest deployment option.
#
# ==============================================================================

provider "azurerm" {
  features {}
}

provider "azuread" {}

module "cxm_integration" {
  source = "../../"

  # Authentication (client_secret is the default)
  authentication_method = "client_secret"

  # Enable all features
  enable_asset_discovery       = true
  enable_billing_export_access = true
  enable_activity_log_access   = true

  # Storage accounts for cost and activity data (must already exist)
  billing_export_storage_account_name   = "mycompanycostexports"
  billing_export_storage_resource_group = "finops-rg"
  billing_export_focus_path             = "az://cost-exports/daily/cxm-daily-export-focus/**/*.parquet"

  activity_log_storage_account_name   = "mycompanyactivitylogs"
  activity_log_storage_resource_group = "logging-rg"

  tags = {
    environment = "production"
    managed-by  = "terraform"
  }
}

# ==============================================================================
# Outputs - Provide these to CXM
# ==============================================================================

output "cxm_onboarding_values" {
  description = "Values to provide to CXM during onboarding"
  value       = module.cxm_integration.cxm_onboarding_values
  sensitive   = true
}

output "tenant_id" {
  description = "Azure AD Tenant ID"
  value       = module.cxm_integration.tenant_id
}

output "client_id" {
  description = "Azure AD Application (Client) ID"
  value       = module.cxm_integration.client_id
}

output "features_enabled" {
  description = "Summary of enabled features"
  value       = module.cxm_integration.features_enabled
}
