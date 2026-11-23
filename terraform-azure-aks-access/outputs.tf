# ==============================================================================
# AKS ACCESS MODULE OUTPUTS
# ==============================================================================

output "role_definition_id" {
  description = "GUID of the CXM AKS Reader role, the same in each assignable scope."
  value       = azurerm_role_definition.aks_reader.role_definition_id
}

output "role_name" {
  description = "Name of the custom role."
  value       = azurerm_role_definition.aks_reader.name
}
