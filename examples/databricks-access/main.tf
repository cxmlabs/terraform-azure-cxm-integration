# ==============================================================================
# Databricks Access Example
# ==============================================================================
#
# This example installs the CXM integration and gives its Service Principal
# read-only access to the Databricks system tables, in one configuration.
# Add one databricks provider and one module block per metastore, in one
# workspace of that metastore.
#
# The identity that runs Terraform must be a workspace admin and a metastore
# admin. A metastore admin enables the system schemas first.
#
# ==============================================================================

terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

provider "databricks" {
  host = "https://adb-1234567890123456.7.azuredatabricks.net"
}

module "cxm_integration" {
  source = "../../"

  # Storage accounts for cost and activity data (must already exist)
  billing_export_storage_account_name   = "mycompanycostexports"
  billing_export_storage_resource_group = "finops-rg"
  billing_export_focus_path             = "az://cost-exports/daily/cxm-daily-export-focus/**/*.parquet"

  activity_log_storage_account_name   = "mycompanyactivitylogs"
  activity_log_storage_resource_group = "logging-rg"
}

module "cxm_databricks_access" {
  source = "../../terraform-azure-databricks-access"

  service_principal_application_id = module.cxm_integration.client_id

  # client_id does not wait for the Entra ID service principal of the integration.
  depends_on = [module.cxm_integration]
}

# ==============================================================================
# Outputs - Provide these to CXM
# ==============================================================================

output "cxm_onboarding_values" {
  description = "Values to provide to CXM during onboarding"
  value       = module.cxm_integration.cxm_onboarding_values
  sensitive   = true
}

output "cxm_databricks_values" {
  description = "Databricks values to provide to CXM"
  value = {
    workspace_url    = module.cxm_databricks_access.workspace_url
    sql_warehouse_id = module.cxm_databricks_access.sql_warehouse_id
  }
}
