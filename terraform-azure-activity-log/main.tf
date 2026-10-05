# ==============================================================================
# CXM Activity Log Module
# ==============================================================================
# Provides access to Azure Activity Logs (equivalent to AWS CloudTrail).
#
# Primary use case: Grant read access to existing storage account with activity logs.
# Secondary use case: Optionally create diagnostic settings to capture activity logs.
# ==============================================================================

locals {
  # Determine resource group name
  resource_group_name = var.create_storage_account ? (
    var.storage_account_resource_group != "" ? var.storage_account_resource_group : "${var.prefix}-activity-log-rg-${random_id.uniq.hex}"
  ) : var.storage_account_resource_group

  # Determine storage account name
  storage_account_name = var.create_storage_account && var.storage_account_name == "" ? (
    substr("${var.prefix}actlog${random_id.uniq.hex}", 0, 24)
  ) : var.storage_account_name

  # Get storage account ID
  storage_account_id = var.create_storage_account ? (
    azurerm_storage_account.cxm[0].id
  ) : data.azurerm_storage_account.existing[0].id

  # Subscriptions to create diagnostic settings for
  diagnostic_subscription_ids = var.create_diagnostic_settings ? (
    length(var.diagnostic_subscriptions) > 0 ? var.diagnostic_subscriptions : [data.azurerm_subscription.primary.subscription_id]
  ) : []
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "azurerm_subscription" "primary" {}

# Reference existing storage account when not creating a new one
data "azurerm_storage_account" "existing" {
  count = var.create_storage_account ? 0 : 1

  name                = var.storage_account_name
  resource_group_name = var.storage_account_resource_group
}

# ==============================================================================
# RANDOM ID FOR UNIQUE NAMING
# ==============================================================================

resource "random_id" "uniq" {
  byte_length = 4
}

# ==============================================================================
# RESOURCE GROUP (Only when creating new storage)
# ==============================================================================

resource "azurerm_resource_group" "cxm" {
  count = var.create_storage_account && var.storage_account_resource_group == "" ? 1 : 0

  name     = local.resource_group_name
  location = var.location
  tags     = merge(var.tags, { "cxm-purpose" = "activity-logs" })
}

# ==============================================================================
# STORAGE ACCOUNT (Only when creating new)
# ==============================================================================

resource "azurerm_storage_account" "cxm" {
  count = var.create_storage_account ? 1 : 0

  name                = local.storage_account_name
  resource_group_name = var.storage_account_resource_group != "" ? var.storage_account_resource_group : azurerm_resource_group.cxm[0].name
  location            = var.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Security settings
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = merge(var.tags, { "cxm-purpose" = "activity-logs" })
}

# ==============================================================================
# CUSTOM ROLE DEFINITION
# ==============================================================================

# ==============================================================================
# STORAGE ACCESS — scoped to the storage account, not its resource group
# ==============================================================================

resource "azurerm_role_definition" "cxm_activity_log_reader_storage" {
  name        = "${var.prefix}-activity-log-storage-reader-${random_id.uniq.hex}"
  scope       = local.storage_account_id
  description = "Allows CXM to read activity-log data from this storage account only"

  permissions {
    actions = concat(
      [
        "Microsoft.Storage/storageAccounts/read",
        "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      ],
      # listKeys returns the account's shared keys: full data-plane access,
      # bypassing RBAC. Reading exports only needs blobs/read below.
      var.grant_storage_account_keys ? ["Microsoft.Storage/storageAccounts/listkeys/action"] : []
    )

    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
    ]
  }

  assignable_scopes = [local.storage_account_id]
}

resource "azurerm_role_assignment" "cxm_activity_log_reader_storage" {
  scope              = local.storage_account_id
  role_definition_id = azurerm_role_definition.cxm_activity_log_reader_storage.role_definition_resource_id
  principal_id       = var.service_principal_id

  skip_service_principal_aad_check = true
}

resource "azurerm_role_definition" "cxm_activity_log_reader" {
  name        = "${var.prefix}-activity-log-reader-${random_id.uniq.hex}"
  scope       = "/subscriptions/${data.azurerm_subscription.primary.subscription_id}"
  description = "Allows CXM to read activity-log configuration metadata in this resource group"

  permissions {
    actions = [
      # Resource group read
      "Microsoft.Resources/subscriptions/resourceGroups/read",

      # Event Grid (for future notifications)
      "Microsoft.EventGrid/eventSubscriptions/read",

      # Diagnostic settings read
      "Microsoft.Insights/diagnosticSettings/read"
    ]
  }

  assignable_scopes = [
    "/subscriptions/${data.azurerm_subscription.primary.subscription_id}"
  ]
}

# ==============================================================================
# ROLE ASSIGNMENT
# ==============================================================================

resource "azurerm_role_assignment" "cxm_activity_log_reader" {
  scope              = "/subscriptions/${data.azurerm_subscription.primary.subscription_id}/resourceGroups/${local.resource_group_name}"
  role_definition_id = azurerm_role_definition.cxm_activity_log_reader.role_definition_resource_id
  principal_id       = var.service_principal_id

  skip_service_principal_aad_check = true
}

# ==============================================================================
# WAIT FOR ROLE PROPAGATION
# ==============================================================================

resource "time_sleep" "wait_for_role" {
  create_duration = var.wait_time

  depends_on = [azurerm_role_assignment.cxm_activity_log_reader]
}

# ==============================================================================
# DIAGNOSTIC SETTINGS (Optional)
# ==============================================================================

resource "azurerm_monitor_diagnostic_setting" "cxm" {
  for_each = var.create_diagnostic_settings && var.create_storage_account ? toset(local.diagnostic_subscription_ids) : toset([])

  name               = "${var.diagnostic_settings_name}-${random_id.uniq.hex}"
  target_resource_id = "/subscriptions/${each.value}"
  storage_account_id = local.storage_account_id

  # Enable each configured log category
  dynamic "enabled_log" {
    for_each = var.log_categories
    content {
      category = enabled_log.value
    }
  }

  # Ignore changes to log_analytics_destination_type as per Azure provider recommendations
  lifecycle {
    ignore_changes = [log_analytics_destination_type]
  }

  depends_on = [time_sleep.wait_for_role]
}

# ==============================================================================
# VALIDATION
# ==============================================================================

resource "terraform_data" "validate_existing_storage" {
  count = var.create_storage_account ? 0 : 1

  lifecycle {
    precondition {
      condition     = var.storage_account_name != ""
      error_message = "storage_account_name is required when create_storage_account is false."
    }

    precondition {
      condition     = var.storage_account_resource_group != ""
      error_message = "storage_account_resource_group is required when create_storage_account is false."
    }
  }
}
