# ==============================================================================
# AKS ACCESS MODULE OUTPUTS
# ==============================================================================

output "role_definition_id" {
  description = "GUID of the CXM AKS Reader role, the same in each assignable scope."
  value       = azurerm_role_definition.aks_reader.role_definition_id
}

output "assignment_scopes" {
  description = "The scopes of the role assignments, one /subscriptions/<id> for each subscription."
  value       = sort(keys(azurerm_role_assignment.aks_reader))
}

output "principal_ids" {
  description = "The principal IDs of the role assignments."
  value       = distinct([for a in azurerm_role_assignment.aks_reader : a.principal_id])
}

output "role_name" {
  description = "Name of the custom role."
  value       = azurerm_role_definition.aks_reader.name
}
