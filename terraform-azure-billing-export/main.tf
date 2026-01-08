# ==============================================================================
# CXM Billing Export Module
# ==============================================================================
# Provides access to Azure Cost Management exports (equivalent to AWS CUR).
#
# Primary use case: Grant read access to existing storage account with exports.
# Secondary use case: Optionally create new exports with CXM-preferred settings.
# ==============================================================================

locals {
  # Determine resource group name
  resource_group_name = var.create_storage_account ? (
    var.storage_account_resource_group != "" ? var.storage_account_resource_group : "${var.prefix}-billing-rg-${random_id.uniq.hex}"
  ) : var.storage_account_resource_group

  # Determine storage account name
  storage_account_name = var.create_storage_account && var.storage_account_name == "" ? (
    substr("${var.prefix}billing${random_id.uniq.hex}", 0, 24)
  ) : var.storage_account_name

  # Get storage account ID for role assignment scope
  storage_account_id = var.create_storage_account ? (
    azurerm_storage_account.cxm[0].id
  ) : data.azurerm_storage_account.existing[0].id

  # Subscriptions to create exports for
  export_subscription_ids = var.create_cost_exports ? (
    length(var.export_subscriptions) > 0 ? var.export_subscriptions : [data.azurerm_subscription.primary.subscription_id]
  ) : []

  # Storage container ID (for exports)
  storage_container_id = var.create_storage_account ? (
    azurerm_storage_container.cxm[0].id
  ) : null
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
  tags     = merge(var.tags, { "cxm-purpose" = "billing-exports" })
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

  tags = merge(var.tags, { "cxm-purpose" = "billing-exports" })
}

# ==============================================================================
# STORAGE CONTAINER (Only when creating new storage)
# ==============================================================================

resource "azurerm_storage_container" "cxm" {
  count = var.create_storage_account ? 1 : 0

  name                  = "${var.prefix}-cost-exports"
  storage_account_id    = azurerm_storage_account.cxm[0].id
  container_access_type = "private"
}

# ==============================================================================
# CUSTOM ROLE DEFINITION
# ==============================================================================

resource "azurerm_role_definition" "cxm_billing_reader" {
  name        = "${var.prefix}-billing-export-reader-${random_id.uniq.hex}"
  scope       = "/subscriptions/${data.azurerm_subscription.primary.subscription_id}"
  description = "Allows CXM to read cost export data from the storage account"

  permissions {
    actions = [
      # Resource group read
      "Microsoft.Resources/subscriptions/resourceGroups/read",

      # Storage account read
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/listkeys/action",

      # Event Grid (for future notifications)
      "Microsoft.EventGrid/eventSubscriptions/read",

      # Cost Management exports read
      "Microsoft.CostManagement/exports/read"
    ]

    data_actions = [
      # Read blob data
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
    ]
  }

  assignable_scopes = [
    "/subscriptions/${data.azurerm_subscription.primary.subscription_id}"
  ]
}

# ==============================================================================
# ROLE ASSIGNMENT
# ==============================================================================

resource "azurerm_role_assignment" "cxm_billing_reader" {
  scope              = "/subscriptions/${data.azurerm_subscription.primary.subscription_id}/resourceGroups/${local.resource_group_name}"
  role_definition_id = azurerm_role_definition.cxm_billing_reader.role_definition_resource_id
  principal_id       = var.service_principal_id

  skip_service_principal_aad_check = true
}

# ==============================================================================
# WAIT FOR ROLE PROPAGATION
# ==============================================================================

resource "time_sleep" "wait_for_role" {
  create_duration = var.wait_time

  depends_on = [azurerm_role_assignment.cxm_billing_reader]
}

# ==============================================================================
# COST MANAGEMENT EXPORTS - LEGACY FORMAT (Optional)
# ==============================================================================

resource "azurerm_subscription_cost_management_export" "cxm" {
  for_each = var.create_cost_exports && var.create_storage_account && var.export_format == "legacy" ? toset(local.export_subscription_ids) : toset([])

  name            = "${var.prefix}-export-${random_id.uniq.hex}"
  subscription_id = "/subscriptions/${each.value}"

  recurrence_type              = var.export_recurrence
  recurrence_period_start_date = formatdate("YYYY-MM-DD'T'00:00:00'Z'", timestamp())
  recurrence_period_end_date   = formatdate("YYYY-MM-DD'T'00:00:00'Z'", timeadd(timestamp(), "87600h")) # ~10 years

  export_data_storage_location {
    container_id     = local.storage_container_id
    root_folder_path = var.root_folder_path
  }

  export_data_options {
    type       = var.export_type
    time_frame = "MonthToDate"
  }

  depends_on = [time_sleep.wait_for_role]
}

# ==============================================================================
# COST MANAGEMENT EXPORTS - FOCUS FORMAT (Optional)
# ==============================================================================
# Uses azapi provider to create FOCUS exports via Azure REST API
# FOCUS = FinOps Open Cost and Usage Specification (cross-cloud standard)

resource "azapi_resource" "focus_export" {
  for_each = var.create_cost_exports && var.create_storage_account && var.export_format == "focus" ? toset(local.export_subscription_ids) : toset([])

  type      = "Microsoft.CostManagement/exports@2024-08-01"
  name      = "${var.prefix}-focus-export-${random_id.uniq.hex}"
  parent_id = "/subscriptions/${each.value}"

  # Disable schema validation as FOCUS is not in the published schema yet
  schema_validation_enabled = false

  body = {
    properties = {
      definition = {
        type      = "FocusCost"
        timeframe = "MonthToDate"
        dataSet = {
          granularity = "Daily"
          configuration = {
            dataVersion = var.focus_version
          }
        }
      }
      deliveryInfo = {
        destination = {
          resourceId     = local.storage_account_id
          container      = azurerm_storage_container.cxm[0].name
          rootFolderPath = var.root_folder_path
          type           = "AzureBlob"
        }
      }
      schedule = {
        status     = "Active"
        recurrence = var.export_recurrence
        recurrencePeriod = {
          from = formatdate("YYYY-MM-DD'T'00:00:00'Z'", timestamp())
          to   = formatdate("YYYY-MM-DD'T'00:00:00'Z'", timeadd(timestamp(), "87600h"))
        }
      }
      format                = "Parquet"
      partitionData         = true
      dataOverwriteBehavior = "OverwritePreviousReport"
      compressionMode       = "snappy"
    }
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
