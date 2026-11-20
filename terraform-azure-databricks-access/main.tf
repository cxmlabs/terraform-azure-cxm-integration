# ==============================================================================
# CXM Databricks Access
# ==============================================================================
#
# Gives the CXM Service Principal read-only access to the Databricks system
# tables of one metastore, and a dedicated SQL warehouse to query them.
# Call this module once per metastore, in one workspace of that metastore.
#
# ==============================================================================

data "databricks_current_config" "this" {}

resource "databricks_service_principal" "cxm" {
  application_id        = var.service_principal_application_id
  databricks_sql_access = true
  force                 = true
}

# databricks_grant is additive: it keeps the grants of other principals on the system catalog.
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
}

resource "databricks_sql_endpoint" "cxm" {
  name                      = "cxm"
  cluster_size              = "2X-Small"
  auto_stop_mins            = 10
  max_num_clusters          = 1
  warehouse_type            = "PRO"
  enable_serverless_compute = var.warehouse_serverless
}

# databricks_permissions owns the full permission list of the cxm warehouse.
resource "databricks_permissions" "cxm_warehouse" {
  sql_endpoint_id = databricks_sql_endpoint.cxm.id

  access_control {
    service_principal_name = databricks_service_principal.cxm.application_id
    permission_level       = "CAN_USE"
  }
}
