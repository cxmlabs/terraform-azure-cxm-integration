# ==============================================================================
# CXM Service Principal Module
# ==============================================================================
# Creates an Azure AD Application and Service Principal for CXM to access
# Azure resources. Supports two authentication methods:
# - client_secret: Traditional client secret (password)
# - federated_credential: AWS OIDC-based authentication (no secrets)
# ==============================================================================

locals {
  # Determine if we should create resources
  create_resources = !var.dry_run

  # Compute outputs based on whether resources were created
  client_id = local.create_resources ? azuread_application.cxm[0].client_id : ""

  application_object_id = local.create_resources ? azuread_application.cxm[0].object_id : ""

  service_principal_id = local.create_resources ? azuread_service_principal.cxm[0].object_id : ""

  client_secret = (
    local.create_resources && var.authentication_method == "client_secret"
    ? azuread_application_password.client_secret[0].value
    : null
  )
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

data "azuread_client_config" "current" {}

# ==============================================================================
# AZURE AD APPLICATION
# ==============================================================================

resource "azuread_application" "cxm" {
  count = local.create_resources ? 1 : 0

  display_name = var.application_name

  owners = length(var.application_owners) > 0 ? var.application_owners : [data.azuread_client_config.current.object_id]

  # CXM branding
  logo_image    = filebase64("${path.module}/../media/logo.png")
  marketing_url = "https://www.cxmlabs.io/"

  web {
    homepage_url = "https://www.cxmlabs.io/"
  }

  # Sign in audience - single tenant only
  sign_in_audience = "AzureADMyOrg"

  # Tags for identification
  tags = ["CXM", "FinOps", "CloudExMachina"]
}

# ==============================================================================
# SERVICE PRINCIPAL
# ==============================================================================

resource "azuread_service_principal" "cxm" {
  count = local.create_resources ? 1 : 0

  client_id = azuread_application.cxm[0].client_id

  owners = length(var.application_owners) > 0 ? var.application_owners : [data.azuread_client_config.current.object_id]

  # Notes for identification
  notes = "CXM Asset Crawler - FinOps Cloud Integration"

  tags = ["CXM", "FinOps", "CloudExMachina"]
}

# ==============================================================================
# CLIENT SECRET (Only for client_secret authentication)
# ==============================================================================

resource "azuread_application_password" "client_secret" {
  count = local.create_resources && var.authentication_method == "client_secret" ? 1 : 0

  application_id = azuread_application.cxm[0].id
  display_name   = "CXM Client Secret"
  end_date       = var.client_secret_end_date

  # Ensure service principal is created first
  depends_on = [azuread_service_principal.cxm]
}

# ==============================================================================
# FEDERATED CREDENTIAL (Only for federated_credential authentication)
# ==============================================================================

resource "azuread_application_federated_identity_credential" "cxm_aws" {
  count = local.create_resources && var.authentication_method == "federated_credential" ? 1 : 0

  application_id = azuread_application.cxm[0].id
  display_name   = "CXM AWS Workload Identity"
  description    = "Trust CXM's AWS workload to authenticate without secrets"

  # AWS STS as the OIDC issuer
  issuer = "https://sts.amazonaws.com"

  # The specific AWS IAM role that can authenticate
  # This should match the role ARN provided by CXM
  subject = var.cxm_aws_role_arn

  # Audience - Azure AD expects this value for federated credentials
  audiences = ["api://AzureADTokenExchange"]

  # Ensure service principal is created first
  depends_on = [azuread_service_principal.cxm]
}

# ==============================================================================
# DIRECTORY READER ROLE
# ==============================================================================

# Reference the Directory Readers built-in role
resource "azuread_directory_role" "directory_readers" {
  count = local.create_resources && var.enable_directory_reader ? 1 : 0

  display_name = "Directory Readers"
}

# Wait for Azure AD propagation before assigning the role
resource "time_sleep" "wait_for_service_principal" {
  count = local.create_resources ? 1 : 0

  create_duration = "60s"

  depends_on = [azuread_service_principal.cxm]
}

# Assign Directory Readers role to the service principal
resource "azuread_directory_role_assignment" "cxm_directory_reader" {
  count = local.create_resources && var.enable_directory_reader ? 1 : 0

  role_id             = azuread_directory_role.directory_readers[0].template_id
  principal_object_id = azuread_service_principal.cxm[0].object_id

  depends_on = [time_sleep.wait_for_service_principal]
}

# ==============================================================================
# VALIDATION
# ==============================================================================

# Validate that federated credential variables are provided when needed
resource "terraform_data" "validate_federated_credential_vars" {
  count = var.authentication_method == "federated_credential" ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.cxm_aws_account_id != null && var.cxm_aws_account_id != ""
      error_message = "cxm_aws_account_id is required when authentication_method is 'federated_credential'."
    }

    precondition {
      condition     = var.cxm_aws_role_arn != null && var.cxm_aws_role_arn != ""
      error_message = "cxm_aws_role_arn is required when authentication_method is 'federated_credential'."
    }
  }
}
