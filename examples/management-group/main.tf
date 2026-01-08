# ==============================================================================
# Management Group Example
# ==============================================================================
#
# This example deploys the CXM integration at the Management Group level,
# granting access to all subscriptions under the management group.
#
# This is ideal for large organizations with many subscriptions.
#
# ==============================================================================

provider "azurerm" {
  features {}
}

provider "azuread" {}

module "cxm_integration" {
  source = "../../"

  # Authentication
  authentication_method = "client_secret"

  # Grant access at Management Group level
  use_management_group = true
  management_group_id  = "00000000-0000-0000-0000-000000000000" # Replace with your MG ID

  # Enable features
  enable_asset_discovery       = true
  enable_billing_export_access = true
  enable_activity_log_access   = true

  # Storage accounts for cost and activity data
  billing_export_storage_account_name   = "mycompanycostexports"
  billing_export_storage_resource_group = "finops-rg"

  activity_log_storage_account_name   = "mycompanyactivitylogs"
  activity_log_storage_resource_group = "logging-rg"

  tags = {
    environment = "production"
    managed-by  = "terraform"
  }
}

# ==============================================================================
# Outputs
# ==============================================================================

output "cxm_onboarding_values" {
  description = "Values to provide to CXM during onboarding"
  value       = module.cxm_integration.cxm_onboarding_values
  sensitive   = true
}

output "management_group_id" {
  description = "Management Group where access was granted"
  value       = module.cxm_integration.management_group_id
}

output "access_scope" {
  description = "The scope type used for access"
  value       = module.cxm_integration.access_scope
}
