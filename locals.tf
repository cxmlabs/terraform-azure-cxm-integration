# ==============================================================================
# CXM Azure Integration - Local Values
# ==============================================================================

locals {
  # =============================================================================
  # FEATURE FLAGS
  # =============================================================================

  # Determine if we should create a new Service Principal or use existing
  create_service_principal = !var.use_existing_ad_application

  # Feature enablement
  enable_asset_discovery     = var.enable_asset_discovery
  enable_billing_export      = var.enable_billing_export_access && var.billing_export_storage_account_name != ""
  enable_activity_log        = var.enable_activity_log_access && var.activity_log_storage_account_name != ""

  # =============================================================================
  # IDENTITY VALUES
  # =============================================================================

  # Client ID - from new module or existing
  client_id = local.create_service_principal ? (
    module.service_principal[0].client_id
  ) : var.existing_client_id

  # Service Principal ID - from new module or existing
  service_principal_id = local.create_service_principal ? (
    module.service_principal[0].service_principal_id
  ) : var.existing_service_principal_id

  # Client Secret - from new module or existing (only for client_secret auth)
  client_secret = var.authentication_method == "client_secret" ? (
    local.create_service_principal ? module.service_principal[0].client_secret : var.existing_client_secret
  ) : null

  # =============================================================================
  # SUBSCRIPTION LIST
  # =============================================================================

  # Get the list of enabled subscription IDs from the subscription enablement module
  enabled_subscription_ids = var.enable_asset_discovery ? (
    module.subscription_enablement[0].subscription_ids
  ) : []

  # =============================================================================
  # TAGS
  # =============================================================================

  # Merge default tags with user-provided tags
  default_tags = {
    "managed-by" = "terraform"
    "cxm"        = "true"
  }

  tags = merge(local.default_tags, var.tags)
}
