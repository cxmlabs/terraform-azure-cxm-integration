# ==============================================================================
# CXM Subscription Enablement Module
# ==============================================================================
# Grants read access to Azure subscriptions for CXM asset discovery.
# Supports either:
# - Individual subscription-level access
# - Management group-level access (inherits to all child subscriptions)
# ==============================================================================

locals {
  # Determine which subscriptions to enable based on configuration
  subscription_ids = var.use_management_group ? [] : (
    var.all_subscriptions ? (
      # Get all enabled subscriptions, excluding any in the exclusion list
      [
        for s in data.azurerm_subscriptions.available.subscriptions :
        s.subscription_id
        if s.state == "Enabled" && !contains(var.subscription_exclusions, s.subscription_id)
      ]
    ) : (
      # Use provided subscription IDs, or default to primary subscription
      length(var.subscription_ids) > 0 ? var.subscription_ids : [data.azurerm_subscription.primary.subscription_id]
    )
  )
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

# Get the primary (current) subscription
data "azurerm_subscription" "primary" {}

# Get all available subscriptions in the tenant
data "azurerm_subscriptions" "available" {}

# Get management group data if using management group access
data "azurerm_management_group" "target" {
  count = var.use_management_group ? 1 : 0
  name  = var.management_group_id
}

# ==============================================================================
# SUBSCRIPTION-LEVEL ROLE ASSIGNMENTS
# ==============================================================================

# Reader role - provides read access to all resources
resource "azurerm_role_assignment" "reader" {
  for_each = var.use_management_group ? toset([]) : toset(local.subscription_ids)

  scope                = "/subscriptions/${each.value}"
  role_definition_name = "Reader"
  principal_id         = var.service_principal_id

  # Skip if the assignment already exists
  skip_service_principal_aad_check = true
}

# Monitoring Reader role - provides read access to monitoring data
resource "azurerm_role_assignment" "monitoring_reader" {
  for_each = var.use_management_group ? toset([]) : toset(local.subscription_ids)

  scope                = "/subscriptions/${each.value}"
  role_definition_name = "Monitoring Reader"
  principal_id         = var.service_principal_id

  skip_service_principal_aad_check = true
}

# Key Vault Reader role - provides read access to key vault metadata (not secrets)
resource "azurerm_role_assignment" "key_vault_reader" {
  for_each = var.use_management_group ? toset([]) : toset(local.subscription_ids)

  scope                = "/subscriptions/${each.value}"
  role_definition_name = "Key Vault Reader"
  principal_id         = var.service_principal_id

  skip_service_principal_aad_check = true
}

# ==============================================================================
# MANAGEMENT GROUP-LEVEL ROLE ASSIGNMENTS
# ==============================================================================

# Reader role at management group level
resource "azurerm_role_assignment" "mg_reader" {
  count = var.use_management_group ? 1 : 0

  scope                = data.azurerm_management_group.target[0].id
  role_definition_name = "Reader"
  principal_id         = var.service_principal_id

  skip_service_principal_aad_check = true
}

# Key Vault Reader role at management group level
resource "azurerm_role_assignment" "mg_key_vault_reader" {
  count = var.use_management_group ? 1 : 0

  scope                = data.azurerm_management_group.target[0].id
  role_definition_name = "Key Vault Reader"
  principal_id         = var.service_principal_id

  skip_service_principal_aad_check = true
}

# Note: Monitoring Reader at MG level inherits from Reader, so we don't need
# to explicitly assign it when using management groups.

# ==============================================================================
# VALIDATION
# ==============================================================================

resource "terraform_data" "validate_management_group" {
  count = var.use_management_group ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.management_group_id != ""
      error_message = "management_group_id is required when use_management_group is true."
    }
  }
}
