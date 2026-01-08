# ==============================================================================
# ACTIVITY LOG MODULE OUTPUTS
# ==============================================================================

output "storage_account_name" {
  description = "Name of the storage account containing activity logs"
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

output "diagnostic_settings_created" {
  description = "Whether diagnostic settings were created by this module"
  value       = var.create_diagnostic_settings && var.create_storage_account
}

output "diagnostic_subscription_ids" {
  description = "List of subscription IDs for which diagnostic settings were created"
  value       = local.diagnostic_subscription_ids
}

output "diagnostic_settings_name" {
  description = "Name of the diagnostic settings (if created)"
  value       = var.create_diagnostic_settings ? "${var.diagnostic_settings_name}-${random_id.uniq.hex}" : null
}

output "log_categories" {
  description = "Activity log categories being captured"
  value       = var.log_categories
}

output "role_definition_id" {
  description = "ID of the custom role definition created for activity log access"
  value       = azurerm_role_definition.cxm_activity_log_reader.role_definition_resource_id
}
