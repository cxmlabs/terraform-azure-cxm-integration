# ==============================================================================
# SUBSCRIPTION ENABLEMENT MODULE OUTPUTS
# ==============================================================================

output "subscription_ids" {
  description = "List of subscription IDs where access was granted"
  value       = local.subscription_ids
}

output "management_group_id" {
  description = "The Management Group ID where access was granted (if using management group)"
  value       = var.use_management_group ? var.management_group_id : null
}

output "access_scope" {
  description = "The scope type used for access: 'subscription' or 'management_group'"
  value       = var.use_management_group ? "management_group" : "subscription"
}

output "roles_assigned" {
  description = "List of roles assigned by this module"
  value       = var.use_management_group ? ["Reader", "Key Vault Reader"] : ["Reader", "Monitoring Reader", "Key Vault Reader"]
}
