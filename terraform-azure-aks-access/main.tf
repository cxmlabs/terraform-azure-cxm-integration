# ==============================================================================
# CXM AKS Access
# ==============================================================================
#
# Gives the CXM Service Principal read access to the Kubernetes API of the AKS
# clusters that use Entra ID and Azure RBAC: all Kubernetes objects except
# Secrets. Each assignment is on a subscription, because Azure cannot assign a
# custom role with data actions at a management-group scope.
#
# ==============================================================================

data "azurerm_management_group" "target" {
  count = var.use_management_group ? 1 : 0
  name  = var.management_group_id
}

locals {
  management_group_scope = "/providers/Microsoft.Management/managementGroups/${var.management_group_id}"

  subscription_ids = var.use_management_group ? data.azurerm_management_group.target[0].all_subscription_ids : var.subscription_ids

  subscription_scopes = toset([for id in local.subscription_ids : "/subscriptions/${id}"])
}

resource "azurerm_role_definition" "aks_reader" {
  name        = "CXM AKS Reader"
  description = "Read access for CXM to the Kubernetes API of AKS clusters, all objects except Secrets."

  # The first subscription of the sorted list, so a new order does not replace the role.
  scope = var.use_management_group ? local.management_group_scope : "/subscriptions/${sort(var.subscription_ids)[0]}"

  permissions {
    actions          = ["Microsoft.ContainerService/managedClusters/listClusterUserCredential/action"]
    data_actions     = ["Microsoft.ContainerService/managedClusters/*/read"]
    not_data_actions = ["Microsoft.ContainerService/managedClusters/secrets/read"]
  }

  assignable_scopes = var.use_management_group ? [local.management_group_scope] : sort(tolist(local.subscription_scopes))
}

resource "azurerm_role_assignment" "aks_reader" {
  for_each = local.subscription_scopes

  scope                            = each.value
  role_definition_id               = "${each.value}/providers/Microsoft.Authorization/roleDefinitions/${azurerm_role_definition.aks_reader.role_definition_id}"
  principal_id                     = var.service_principal_id
  skip_service_principal_aad_check = true
}
