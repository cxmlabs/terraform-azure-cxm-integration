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

# Only the subscriptions in the state Enabled can take a role assignment.
data "azurerm_subscriptions" "available" {
  count = var.use_management_group ? 1 : 0
}

# The subscription of the provider. It does not move when subscription_ids change.
data "azurerm_subscription" "primary" {}

locals {
  management_group_scope = "/providers/Microsoft.Management/managementGroups/${var.management_group_id}"

  enabled_subscription_ids = var.use_management_group ? [
    for s in data.azurerm_subscriptions.available[0].subscriptions : s.subscription_id if s.state == "Enabled"
  ] : []

  subscription_ids = var.use_management_group ? [
    for id in data.azurerm_management_group.target[0].all_subscription_ids : id if contains(local.enabled_subscription_ids, id) && !contains(var.subscription_exclusions, id)
  ] : var.subscription_ids

  primary_scope = "/subscriptions/${data.azurerm_subscription.primary.subscription_id}"

  subscription_scopes = toset([for id in local.subscription_ids : "/subscriptions/${id}"])
}

resource "azurerm_role_definition" "aks_reader" {
  name        = "CXM AKS Reader"
  description = "Read access for CXM to the Kubernetes API of AKS clusters, all objects except Secrets."

  # The subscription of the provider, so a new list of subscriptions does not replace the role.
  scope = var.use_management_group ? local.management_group_scope : local.primary_scope

  permissions {
    actions          = ["Microsoft.ContainerService/managedClusters/listClusterUserCredential/action"]
    data_actions     = ["Microsoft.ContainerService/managedClusters/*/read"]
    not_data_actions = ["Microsoft.ContainerService/managedClusters/secrets/read"]
  }

  assignable_scopes = var.use_management_group ? [local.management_group_scope] : sort(distinct(concat([local.primary_scope], tolist(local.subscription_scopes))))

  lifecycle {
    precondition {
      condition     = var.use_management_group || length(var.subscription_ids) > 0
      error_message = "subscription_ids must hold at least one subscription when use_management_group is false."
    }
  }
}

resource "azurerm_role_assignment" "aks_reader" {
  for_each = local.subscription_scopes

  scope                            = each.value
  role_definition_id               = "${each.value}/providers/Microsoft.Authorization/roleDefinitions/${azurerm_role_definition.aks_reader.role_definition_id}"
  principal_id                     = var.service_principal_id
  skip_service_principal_aad_check = true
}
