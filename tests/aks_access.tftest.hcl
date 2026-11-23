# ==============================================================================
# AKS Access - plan tests with mock providers (no Azure tenant is read)
# ==============================================================================

mock_provider "azurerm" {
  mock_data "azurerm_subscription" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000001"
    }
  }

  mock_data "azurerm_subscriptions" {
    defaults = {
      subscriptions = [
        { subscription_id = "00000000-0000-0000-0000-000000000003", state = "Enabled" },
        { subscription_id = "00000000-0000-0000-0000-000000000004", state = "Enabled" },
      ]
    }
  }

  mock_data "azurerm_management_group" {
    defaults = {
      id                   = "/providers/Microsoft.Management/managementGroups/mg-cxm"
      all_subscription_ids = ["00000000-0000-0000-0000-000000000003", "00000000-0000-0000-0000-000000000004"]
    }
  }
}

mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = { object_id = "00000000-0000-0000-0000-0000000000bb" }
  }
}

mock_provider "azapi" {}
mock_provider "random" {}
mock_provider "time" {}

# The submodule runs read the role and its assignments directly: a run on the
# root module cannot read the resources of a child module.
run "subscription_scope" {
  command = plan

  module {
    source = "./terraform-azure-aks-access"
  }

  providers = {
    azurerm = azurerm
  }

  variables {
    service_principal_id = "00000000-0000-0000-0000-0000000000cc"
    subscription_ids     = ["00000000-0000-0000-0000-000000000002", "00000000-0000-0000-0000-000000000001"]
  }

  assert {
    condition     = azurerm_role_definition.aks_reader.name == "CXM AKS Reader"
    error_message = "The role name must be CXM AKS Reader."
  }

  assert {
    condition = (
      toset(azurerm_role_definition.aks_reader.permissions[0].actions) == toset(["Microsoft.ContainerService/managedClusters/listClusterUserCredential/action"]) &&
      toset(azurerm_role_definition.aks_reader.permissions[0].data_actions) == toset(["Microsoft.ContainerService/managedClusters/*/read"]) &&
      toset(azurerm_role_definition.aks_reader.permissions[0].not_data_actions) == toset(["Microsoft.ContainerService/managedClusters/secrets/read"]) &&
      try(length(azurerm_role_definition.aks_reader.permissions[0].not_actions), 0) == 0
    )
    error_message = "The role permissions are not the permissions of the contract."
  }

  assert {
    condition     = toset(azurerm_role_definition.aks_reader.assignable_scopes) == toset(["/subscriptions/00000000-0000-0000-0000-000000000001", "/subscriptions/00000000-0000-0000-0000-000000000002"])
    error_message = "The assignable scopes must be the two subscriptions."
  }

  assert {
    condition     = azurerm_role_definition.aks_reader.scope == "/subscriptions/00000000-0000-0000-0000-000000000001"
    error_message = "The definition scope must be the subscription of the provider."
  }

  assert {
    condition     = keys(azurerm_role_assignment.aks_reader) == ["/subscriptions/00000000-0000-0000-0000-000000000001", "/subscriptions/00000000-0000-0000-0000-000000000002"]
    error_message = "There must be one assignment for each subscription, keyed by its scope."
  }

  assert {
    condition     = alltrue([for k, a in azurerm_role_assignment.aks_reader : a.scope == k && a.principal_id == "00000000-0000-0000-0000-0000000000cc"])
    error_message = "Each assignment must give the role to the CXM service principal on its subscription."
  }
}

run "scope_does_not_move_with_the_list" {
  command = plan

  module {
    source = "./terraform-azure-aks-access"
  }

  providers = {
    azurerm = azurerm
  }

  variables {
    service_principal_id = "00000000-0000-0000-0000-0000000000cc"
    subscription_ids     = ["00000000-0000-0000-0000-000000000002", "00000000-0000-0000-0000-000000000000"]
  }

  assert {
    condition     = azurerm_role_definition.aks_reader.scope == "/subscriptions/00000000-0000-0000-0000-000000000001"
    error_message = "The definition scope must not change when the first subscription changes."
  }
}

run "empty_subscription_list" {
  command = plan

  module {
    source = "./terraform-azure-aks-access"
  }

  providers = {
    azurerm = azurerm
  }

  variables {
    service_principal_id = "00000000-0000-0000-0000-0000000000cc"
    subscription_ids     = []
  }

  expect_failures = [azurerm_role_definition.aks_reader]
}

run "management_group_scope" {
  command = plan

  module {
    source = "./terraform-azure-aks-access"
  }

  providers = {
    azurerm = azurerm
  }

  variables {
    service_principal_id = "00000000-0000-0000-0000-0000000000cc"
    use_management_group = true
    management_group_id  = "mg-cxm"
  }

  assert {
    condition     = azurerm_role_definition.aks_reader.assignable_scopes == tolist(["/providers/Microsoft.Management/managementGroups/mg-cxm"])
    error_message = "The assignable scope must be the management group only."
  }

  assert {
    condition     = keys(azurerm_role_assignment.aks_reader) == ["/subscriptions/00000000-0000-0000-0000-000000000003", "/subscriptions/00000000-0000-0000-0000-000000000004"]
    error_message = "There must be one assignment for each subscription of the management group."
  }

  assert {
    condition     = !contains([for a in azurerm_role_assignment.aks_reader : a.scope], "/providers/Microsoft.Management/managementGroups/mg-cxm")
    error_message = "No assignment may use the management-group scope."
  }

  assert {
    condition     = alltrue([for a in azurerm_role_assignment.aks_reader : a.principal_id == "00000000-0000-0000-0000-0000000000cc"])
    error_message = "Each assignment must give the role to the CXM service principal."
  }
}

run "disabled_subscription_skipped" {
  command = plan

  module {
    source = "./terraform-azure-aks-access"
  }

  providers = {
    azurerm = azurerm
  }

  override_data {
    target = data.azurerm_subscriptions.available
    values = {
      subscriptions = [
        { subscription_id = "00000000-0000-0000-0000-000000000003", state = "Enabled" },
        { subscription_id = "00000000-0000-0000-0000-000000000004", state = "Disabled" },
      ]
    }
  }

  variables {
    service_principal_id = "00000000-0000-0000-0000-0000000000cc"
    use_management_group = true
    management_group_id  = "mg-cxm"
  }

  assert {
    condition     = keys(azurerm_role_assignment.aks_reader) == ["/subscriptions/00000000-0000-0000-0000-000000000003"]
    error_message = "A Disabled subscription must get no assignment."
  }
}

run "management_group_exclusion" {
  command = plan

  module {
    source = "./terraform-azure-aks-access"
  }

  providers = {
    azurerm = azurerm
  }

  variables {
    service_principal_id    = "00000000-0000-0000-0000-0000000000cc"
    use_management_group    = true
    management_group_id     = "mg-cxm"
    subscription_exclusions = ["00000000-0000-0000-0000-000000000003"]
  }

  assert {
    condition     = keys(azurerm_role_assignment.aks_reader) == ["/subscriptions/00000000-0000-0000-0000-000000000004"]
    error_message = "An excluded subscription must get no assignment."
  }
}

# The root run creates a new service principal in management-group mode, so the
# plan proves that the assignments do not wait for the service principal.
run "root_wiring" {
  command = plan

  variables {
    enable_billing_export_access = false
    enable_activity_log_access   = false
    enable_aks_access            = true
    use_management_group         = true
    management_group_id          = "mg-cxm"
  }

  assert {
    condition     = length(module.aks_access) == 1 && module.aks_access[0].role_name == "CXM AKS Reader"
    error_message = "enable_aks_access must create one instance of module.aks_access."
  }

  assert {
    condition     = output.features_enabled.aks_access == true
    error_message = "features_enabled.aks_access must be true."
  }
}

run "disabled_by_default" {
  command = plan

  variables {
    enable_billing_export_access = false
    enable_activity_log_access   = false
  }

  assert {
    condition     = length(module.aks_access) == 0
    error_message = "module.aks_access must have no instance by default."
  }

  assert {
    condition     = output.features_enabled.aks_access == false
    error_message = "features_enabled.aks_access must be false by default."
  }
}
