# ==============================================================================
# CXM Databricks Access
# ==============================================================================
#
# Gives the CXM Service Principal read-only access to the Databricks system
# tables of one workspace, and a dedicated SQL warehouse to query them.
# Call this module once per workspace, each with its own databricks provider.
#
# ==============================================================================

data "databricks_current_config" "this" {}

resource "databricks_service_principal" "cxm" {
  application_id        = var.service_principal_application_id
  display_name          = var.service_principal_display_name
  databricks_sql_access = true
  force                 = true
}

resource "databricks_system_schema" "this" {
  for_each = var.enable_system_schemas ? setsubtract(toset(var.system_schemas), ["billing"]) : toset([])

  schema = each.value
}

# databricks_grant (not databricks_grants) adds CXM's grants and keeps the grants of other principals.
resource "databricks_grant" "system_catalog" {
  catalog    = "system"
  principal  = databricks_service_principal.cxm.application_id
  privileges = ["USE_CATALOG"]
}

resource "databricks_grant" "system_schemas" {
  for_each = toset(var.system_schemas)

  schema     = "system.${each.value}"
  principal  = databricks_service_principal.cxm.application_id
  privileges = ["USE_SCHEMA", "SELECT"]

  depends_on = [databricks_system_schema.this]
}

resource "databricks_sql_endpoint" "cxm" {
  name                      = var.warehouse_name
  cluster_size              = var.warehouse_cluster_size
  auto_stop_mins            = var.warehouse_auto_stop_mins
  max_num_clusters          = 1
  warehouse_type            = "PRO"
  enable_serverless_compute = var.warehouse_serverless
}

resource "databricks_permissions" "cxm_warehouse" {
  sql_endpoint_id = databricks_sql_endpoint.cxm.id

  access_control {
    service_principal_name = databricks_service_principal.cxm.application_id
    permission_level       = "CAN_USE"
  }
}
