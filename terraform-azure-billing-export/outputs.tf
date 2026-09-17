# ==============================================================================
# BILLING EXPORT MODULE OUTPUTS
# ==============================================================================

output "storage_account_name" {
  description = "Name of the storage account containing cost exports"
  value       = local.storage_account_name
}

output "storage_account_resource_group" {
  description = "Resource group containing the storage account"
  value       = local.resource_group_name
}

output "storage_account_id" {
  description = "Resource ID of the storage account"
  value       = local.storage_account_id
}

output "storage_account_created" {
  description = "Whether a new storage account was created by this module"
  value       = var.create_storage_account
}

output "exports_created" {
  description = "Whether cost exports were created by this module"
  value       = var.create_cost_exports && var.create_storage_account
}

output "export_subscription_ids" {
  description = "List of subscription IDs for which cost exports were created"
  value       = local.export_subscription_ids
}

output "role_definition_id" {
  description = "ID of the custom role definition created for billing export access"
  value       = azurerm_role_definition.cxm_billing_reader.role_definition_resource_id
}

output "focus_path" {
  description = "Glob path to the FOCUS export parquet files (derived when created here, else the caller-provided path)"
  value       = local.focus_path
}
