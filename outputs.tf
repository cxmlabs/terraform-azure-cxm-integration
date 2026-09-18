# ==============================================================================
# CXM Azure Integration - Outputs
# ==============================================================================

# ==============================================================================
# ONBOARDING VALUES - Provide these to CXM
# ==============================================================================

output "cxm_onboarding_values" {
  description = <<-EOT
    Values to provide to CXM during onboarding. The keys match the Azure datasource
    inputs exactly, so this block pastes straight into the CXM onboarding form/API.

    IMPORTANT: If using client_secret authentication, azure_client_secret is sensitive.
    Use `terraform output -json cxm_onboarding_values` to retrieve all values including secrets.
  EOT
  sensitive   = true
  value = {
    azure_tenant_id                      = data.azurerm_subscription.primary.tenant_id
    azure_client_id                      = local.client_id
    authentication_method                = var.authentication_method
    azure_client_secret                  = local.client_secret
    azure_subscription_ids               = local.enabled_subscription_ids
    azure_billing_export_storage_account = local.enable_billing_export ? module.billing_export[0].storage_account_name : null
    azure_billing_export_resource_group  = local.enable_billing_export ? module.billing_export[0].storage_account_resource_group : null
    azure_focus_path                     = local.enable_billing_export ? module.billing_export[0].focus_path : null
  }
}

# ==============================================================================
# TENANT & IDENTITY
# ==============================================================================

output "tenant_id" {
  description = "Azure AD Tenant ID"
  value       = data.azurerm_subscription.primary.tenant_id
}

output "client_id" {
  description = "Azure AD Application (Client) ID"
  value       = local.client_id
}

output "service_principal_id" {
  description = "Service Principal Object ID"
  value       = local.service_principal_id
}

output "client_secret" {
  description = "Client Secret (only when using client_secret authentication method)"
  sensitive   = true
  value       = local.client_secret
}

output "authentication_method" {
  description = "Authentication method configured for CXM access"
  value       = var.authentication_method
}

# ==============================================================================
# SCOPE & ACCESS
# ==============================================================================

output "subscription_ids" {
  description = "List of Azure subscription IDs where CXM has access"
  value       = local.enabled_subscription_ids
}

output "access_scope" {
  description = "The scope type used for access: 'subscription' or 'management_group'"
  value       = var.enable_asset_discovery ? module.subscription_enablement[0].access_scope : null
}

output "management_group_id" {
  description = "Management Group ID where access was granted (if using management group)"
  value       = var.use_management_group ? var.management_group_id : null
}

# ==============================================================================
# BILLING EXPORT
# ==============================================================================

output "billing_export_storage_account" {
  description = "Storage account name for billing exports"
  value       = local.enable_billing_export ? module.billing_export[0].storage_account_name : null
}

output "billing_export_storage_resource_group" {
  description = "Resource group of the billing export storage account"
  value       = local.enable_billing_export ? module.billing_export[0].storage_account_resource_group : null
}

output "billing_export_focus_path" {
  description = "Glob path to the FOCUS export parquet files CXM reads cost data from"
  value       = local.enable_billing_export ? module.billing_export[0].focus_path : null
}

# ==============================================================================
# ACTIVITY LOG
# ==============================================================================

output "activity_log_storage_account" {
  description = "Storage account name for activity logs"
  value       = local.enable_activity_log ? module.activity_log[0].storage_account_name : null
}

output "activity_log_storage_resource_group" {
  description = "Resource group of the activity log storage account"
  value       = local.enable_activity_log ? module.activity_log[0].storage_account_resource_group : null
}

# ==============================================================================
# FEATURE STATUS
# ==============================================================================

output "features_enabled" {
  description = "Summary of which features are enabled"
  value = {
    service_principal_created = local.create_service_principal
    asset_discovery           = local.enable_asset_discovery
    billing_export_access     = local.enable_billing_export
    activity_log_access       = local.enable_activity_log
    directory_reader          = var.enable_directory_reader && local.create_service_principal
  }
}
