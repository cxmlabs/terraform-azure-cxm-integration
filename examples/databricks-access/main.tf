# ==============================================================================
# Databricks Access Example
# ==============================================================================
#
# This example gives the CXM Service Principal read-only access to the system
# tables of one Azure Databricks workspace. Add one provider and one module
# block per workspace.
#
# The identity that runs Terraform must be a workspace admin. To enable the
# system schemas (enable_system_schemas = true), it must also be a metastore admin.
#
# ==============================================================================

terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

provider "databricks" {
  host = "https://adb-1234567890123456.7.azuredatabricks.net"
}

module "cxm_databricks_access" {
  source = "../../terraform-azure-databricks-access"

  # client_id output of the CXM integration module
  service_principal_application_id = "00000000-0000-0000-0000-000000000000"
}

output "cxm_databricks_values" {
  description = "Values to provide to CXM"
  value = {
    workspace_url    = module.cxm_databricks_access.workspace_url
    sql_warehouse_id = module.cxm_databricks_access.sql_warehouse_id
  }
}
