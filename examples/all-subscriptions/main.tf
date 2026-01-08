# ==============================================================================
# All Subscriptions Example
# ==============================================================================
#
# This example deploys the CXM integration to all subscriptions in the tenant,
# with the ability to exclude specific subscriptions.
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

  # Grant access to all subscriptions
  all_subscriptions = true

  # Optionally exclude specific subscriptions (sandbox, dev, etc.)
  subscription_exclusions = [
    # "00000000-0000-0000-0000-000000000001",  # Sandbox subscription
    # "00000000-0000-0000-0000-000000000002",  # Development subscription
  ]

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

output "subscription_ids" {
  description = "List of subscription IDs where CXM has access"
  value       = module.cxm_integration.subscription_ids
}

output "features_enabled" {
  description = "Summary of enabled features"
  value       = module.cxm_integration.features_enabled
}
