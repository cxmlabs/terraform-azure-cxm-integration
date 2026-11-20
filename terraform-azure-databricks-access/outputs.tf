# ==============================================================================
# DATABRICKS ACCESS MODULE OUTPUTS
# ==============================================================================

output "workspace_url" {
  description = "URL of the Databricks workspace. Provide it to CXM."
  value       = data.databricks_current_config.this.host
}

output "sql_warehouse_id" {
  description = "ID of the CXM SQL warehouse. Provide it to CXM."
  value       = databricks_sql_endpoint.cxm.id
}
