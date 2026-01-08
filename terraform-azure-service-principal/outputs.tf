# ==============================================================================
# SERVICE PRINCIPAL MODULE OUTPUTS
# ==============================================================================

output "client_id" {
  description = "The Application (Client) ID of the Azure AD Application"
  value       = local.client_id
}

output "application_object_id" {
  description = "The Object ID of the Azure AD Application"
  value       = local.application_object_id
}

output "service_principal_id" {
  description = "The Object ID of the Service Principal"
  value       = local.service_principal_id
}

output "client_secret" {
  description = "The client secret value (only available when authentication_method = 'client_secret')"
  value       = local.client_secret
  sensitive   = true
}

output "authentication_method" {
  description = "The authentication method configured for this Service Principal"
  value       = var.authentication_method
}

output "created" {
  description = "Indicates whether resources were created by this module"
  value       = local.create_resources
}

output "directory_reader_enabled" {
  description = "Indicates whether Directory Reader role was assigned"
  value       = local.create_resources && var.enable_directory_reader
}
