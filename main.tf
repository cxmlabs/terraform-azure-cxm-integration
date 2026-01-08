# ==============================================================================
# CXM Azure Integration - Root Module
# ==============================================================================
#
# This module enables CXM (Cloud ex Machina) to access your Azure tenant for
# FinOps analysis, cost optimization, and infrastructure recommendations.
#
# Components:
# - Service Principal: Identity for CXM to authenticate to Azure
# - Subscription Enablement: Read access to Azure resources
# - Billing Export Access: Read access to Cost Management exports
# - Activity Log Access: Read access to Activity Logs
#
# ==============================================================================

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "azurerm_subscription" "primary" {}

# ==============================================================================
# SERVICE PRINCIPAL MODULE
# ==============================================================================

module "service_principal" {
  source = "./terraform-azure-service-principal"

  count = local.create_service_principal ? 1 : 0

  # Authentication configuration
  authentication_method = var.authentication_method
  cxm_aws_account_id    = var.cxm_aws_account_id
  cxm_aws_role_arn      = var.cxm_aws_role_arn

  # Application configuration
  application_name        = var.application_name
  enable_directory_reader = var.enable_directory_reader

  # dry_run is false - we want to create resources
  dry_run = false
}

# ==============================================================================
# SUBSCRIPTION ENABLEMENT MODULE
# ==============================================================================

module "subscription_enablement" {
  source = "./terraform-azure-subscription-enablement"

  count = local.enable_asset_discovery ? 1 : 0

  # Service Principal to grant access to
  service_principal_id = local.service_principal_id

  # Scope configuration
  use_management_group    = var.use_management_group
  management_group_id     = var.management_group_id
  all_subscriptions       = var.all_subscriptions
  subscription_ids        = var.subscription_ids
  subscription_exclusions = var.subscription_exclusions

  depends_on = [module.service_principal]
}

# ==============================================================================
# BILLING EXPORT MODULE
# ==============================================================================

module "billing_export" {
  source = "./terraform-azure-billing-export"

  count = local.enable_billing_export ? 1 : 0

  # Service Principal to grant access to
  service_principal_id = local.service_principal_id

  # Storage account configuration
  storage_account_name           = var.billing_export_storage_account_name
  storage_account_resource_group = var.billing_export_storage_resource_group
  create_storage_account         = var.billing_export_create_storage_account
  location                       = var.billing_export_location

  # Cost export configuration
  create_cost_exports = var.billing_export_create_cost_exports
  export_format       = var.billing_export_format

  # Naming
  prefix = var.prefix
  tags   = local.tags

  depends_on = [module.service_principal]
}

# ==============================================================================
# ACTIVITY LOG MODULE
# ==============================================================================

module "activity_log" {
  source = "./terraform-azure-activity-log"

  count = local.enable_activity_log ? 1 : 0

  # Service Principal to grant access to
  service_principal_id = local.service_principal_id

  # Storage account configuration (existing)
  storage_account_name           = var.activity_log_storage_account_name
  storage_account_resource_group = var.activity_log_storage_resource_group
  create_storage_account         = false
  create_diagnostic_settings     = false

  # Naming
  prefix = var.prefix
  tags   = local.tags

  depends_on = [module.service_principal]
}

# ==============================================================================
# VALIDATION
# ==============================================================================

# Validate existing AD application configuration
resource "terraform_data" "validate_existing_app" {
  count = var.use_existing_ad_application ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.existing_client_id != ""
      error_message = "existing_client_id is required when use_existing_ad_application is true."
    }

    precondition {
      condition     = var.existing_service_principal_id != ""
      error_message = "existing_service_principal_id is required when use_existing_ad_application is true."
    }

    precondition {
      condition     = var.authentication_method != "client_secret" || var.existing_client_secret != ""
      error_message = "existing_client_secret is required when use_existing_ad_application is true and authentication_method is 'client_secret'."
    }
  }
}

# Validate billing export configuration
resource "terraform_data" "validate_billing_export" {
  count = var.enable_billing_export_access ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.billing_export_create_storage_account || var.billing_export_storage_account_name != ""
      error_message = "billing_export_storage_account_name is required when enable_billing_export_access is true (unless billing_export_create_storage_account is true)."
    }

    precondition {
      condition     = var.billing_export_create_storage_account || var.billing_export_storage_resource_group != ""
      error_message = "billing_export_storage_resource_group is required when enable_billing_export_access is true (unless billing_export_create_storage_account is true)."
    }

    precondition {
      condition     = !var.billing_export_create_cost_exports || var.billing_export_create_storage_account
      error_message = "billing_export_create_storage_account must be true when billing_export_create_cost_exports is true."
    }
  }
}

# Validate activity log configuration
resource "terraform_data" "validate_activity_log" {
  count = var.enable_activity_log_access ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.activity_log_storage_account_name != ""
      error_message = "activity_log_storage_account_name is required when enable_activity_log_access is true."
    }

    precondition {
      condition     = var.activity_log_storage_resource_group != ""
      error_message = "activity_log_storage_resource_group is required when enable_activity_log_access is true."
    }
  }
}
