# ==============================================================================
# Existing Resources Example - Multi-Subscription, Pre-Created Export
# ==============================================================================
#
# The common production case: a FOCUS Cost Management export and its storage
# account already exist, and CXM is granted read access across several named
# subscriptions. The onboarding output pastes straight into the CXM Azure
# datasource (tenant_id / client_id / client_secret / subscription_ids /
# billing_export_storage_account / resource_group / focus_path).
#
# ==============================================================================

provider "azurerm" {
  features {}
}

provider "azuread" {}

module "cxm_integration" {
  source = "../../"

  authentication_method = "client_secret"

  # Grant read access to a specific list of subscriptions.
  enable_asset_discovery = true
  subscription_ids = [
    "00000000-0000-0000-0000-000000000001",
    "00000000-0000-0000-0000-000000000002",
    "00000000-0000-0000-0000-000000000003",
  ]

  # Existing FOCUS cost export - grant read only (do NOT create).
  enable_billing_export_access          = true
  billing_export_storage_account_name   = "mycompanycostexports"
  billing_export_storage_resource_group = "costandusage-report-rg"
  billing_export_focus_path             = "az://cost-exports/daily/cxm-daily-export-focus/**/*.parquet"

  # Existing activity-log storage - grant read only.
  enable_activity_log_access          = true
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
#
# `terraform output -json cxm_onboarding_values` returns exactly the keys the
# CXM Azure datasource expects, so its result pastes in with no renaming.
# ==============================================================================

output "cxm_onboarding_values" {
  description = "Values to provide to CXM during onboarding (paste-ready)"
  value       = module.cxm_integration.cxm_onboarding_values
  sensitive   = true
}
