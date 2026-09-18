# ==============================================================================
# CXM Azure Integration - Root Module Variables
# ==============================================================================

# ==============================================================================
# AUTHENTICATION CONFIGURATION
# ==============================================================================

variable "authentication_method" {
  type        = string
  default     = "client_secret"
  description = <<-EOT
    Authentication method for CXM to access your Azure tenant.

    Options:

    "client_secret" (Default):
      Creates a client secret (password) for the Azure AD Application.
      - Simple to set up and widely supported
      - The secret will be output and must be provided to CXM during onboarding
      - Requires secure transmission and storage of the secret

    "federated_credential":
      Creates a federated credential that trusts CXM's AWS workload identity.
      - More secure: no secrets are stored in your tenant or transmitted
      - CXM's AWS IAM role is trusted directly via OIDC federation
      - Requires cxm_aws_account_id and cxm_aws_role_arn to be provided
      - Note: Requires CXM backend support for this authentication method
  EOT

  validation {
    condition     = contains(["client_secret", "federated_credential"], var.authentication_method)
    error_message = "authentication_method must be either 'client_secret' or 'federated_credential'."
  }
}

variable "cxm_aws_account_id" {
  type        = string
  default     = null
  description = <<-EOT
    (Required when authentication_method = "federated_credential")

    The AWS Account ID of CXM's SaaS platform.
    Used to establish trust between your Azure AD Application and CXM's AWS workload.
    This value is provided by CXM during onboarding.

    Example: "123456789012"
  EOT
}

variable "cxm_aws_role_arn" {
  type        = string
  default     = null
  description = <<-EOT
    (Required when authentication_method = "federated_credential")

    The ARN of CXM's AWS IAM Role that will access your Azure resources.
    Only this specific AWS role will be able to authenticate to your Azure tenant.
    This value is provided by CXM during onboarding.

    Example: "arn:aws:sts::123456789012:assumed-role/cxm-azure-crawler/*"
  EOT
}

# ==============================================================================
# FEATURE TOGGLES
# ==============================================================================

variable "enable_asset_discovery" {
  type        = bool
  default     = true
  description = <<-EOT
    Enable asset discovery permissions (Reader roles on subscriptions).

    When enabled, grants:
    - Reader role: Read access to all Azure resources
    - Monitoring Reader role: Read access to monitoring data
    - Key Vault Reader role: Read access to Key Vault metadata (not secrets)

    Strongly recommended - required for infrastructure analysis and optimization recommendations.
  EOT
}

variable "enable_billing_export_access" {
  type        = bool
  default     = true
  description = <<-EOT
    Enable access to Cost Management exports storage.

    When enabled, creates a custom role to read cost export data from the specified storage account.
    Required for cost analysis and FinOps recommendations.

    Note: Requires billing_export_storage_account_name and billing_export_storage_resource_group.
  EOT
}

variable "enable_activity_log_access" {
  type        = bool
  default     = true
  description = <<-EOT
    Enable access to Activity Logs storage.

    When enabled, creates a custom role to read activity log data from the specified storage account.
    Recommended for change tracking, security analysis, and audit compliance.

    Note: Requires activity_log_storage_account_name and activity_log_storage_resource_group.
  EOT
}

# ==============================================================================
# SCOPE CONFIGURATION
# ==============================================================================

variable "use_management_group" {
  type        = bool
  default     = false
  description = <<-EOT
    Grant access at the Management Group level instead of individual subscriptions.

    When true:
    - Permissions are granted at the management group level
    - All child subscriptions automatically inherit access
    - More efficient for large organizations
    - Requires management_group_id to be set
    - subscription_ids and all_subscriptions are ignored

    When false (default):
    - Permissions are granted at the subscription level
    - Use subscription_ids or all_subscriptions to specify target subscriptions
  EOT
}

variable "management_group_id" {
  type        = string
  default     = ""
  description = <<-EOT
    (Required when use_management_group = true)

    The ID of the Management Group to grant access to.
    All subscriptions under this management group will be accessible.

    Find this value in:
    - Azure Portal > Management Groups
    - Azure CLI: az account management-group list

    Example: "00000000-0000-0000-0000-000000000000"
  EOT
}

variable "all_subscriptions" {
  type        = bool
  default     = false
  description = <<-EOT
    Grant access to all enabled subscriptions in the tenant.

    When true:
    - Access is granted to all subscriptions visible to the current user
    - Subscriptions in subscription_exclusions are skipped
    - subscription_ids is ignored

    When false (default):
    - Only subscriptions in subscription_ids are enabled
    - If subscription_ids is empty, defaults to the current subscription
  EOT
}

variable "subscription_ids" {
  type        = list(string)
  default     = []
  description = <<-EOT
    List of specific subscription IDs to grant access to.

    If empty and all_subscriptions is false:
    - Defaults to the current subscription (from Azure provider configuration)

    Example: ["00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000002"]
  EOT
}

variable "subscription_exclusions" {
  type        = list(string)
  default     = []
  description = <<-EOT
    List of subscription IDs to exclude when using all_subscriptions = true.
    Has no effect when all_subscriptions = false.

    Use this to skip sandbox, development, or other non-production subscriptions.
  EOT
}

# ==============================================================================
# EXISTING AZURE AD APPLICATION (Optional)
# ==============================================================================

variable "use_existing_ad_application" {
  type        = bool
  default     = false
  description = <<-EOT
    Use an existing Azure AD Application instead of creating a new one.

    When true:
    - No new Application or Service Principal is created
    - existing_client_id and existing_service_principal_id are required
    - If using client_secret auth, existing_client_secret is also required
  EOT
}

variable "existing_client_id" {
  type        = string
  default     = ""
  description = <<-EOT
    (Required when use_existing_ad_application = true)
    The Application (Client) ID of the existing Azure AD Application.
  EOT
}

variable "existing_service_principal_id" {
  type        = string
  default     = ""
  description = <<-EOT
    (Required when use_existing_ad_application = true)
    The Object ID of the existing Service Principal.
  EOT
}

variable "existing_client_secret" {
  type        = string
  default     = ""
  sensitive   = true
  description = <<-EOT
    (Required when use_existing_ad_application = true AND authentication_method = "client_secret")
    The client secret of the existing Azure AD Application.
  EOT
}

# ==============================================================================
# BILLING EXPORT STORAGE CONFIGURATION
# ==============================================================================

variable "billing_export_storage_account_name" {
  type        = string
  default     = ""
  description = <<-EOT
    Name of the storage account containing Cost Management exports.

    Required when enable_billing_export_access = true.
    This should be an existing storage account where cost exports are configured.
  EOT
}

variable "billing_export_storage_resource_group" {
  type        = string
  default     = ""
  description = <<-EOT
    Resource group of the billing export storage account.

    Required when enable_billing_export_access = true (unless billing_export_create_storage_account = true).
  EOT
}

variable "billing_export_create_storage_account" {
  type        = bool
  default     = false
  description = <<-EOT
    Create a new storage account for billing exports instead of using an existing one.

    When true:
    - A new storage account will be created
    - billing_export_storage_account_name and billing_export_storage_resource_group are optional
    - If not provided, names will be auto-generated
  EOT
}

variable "billing_export_create_cost_exports" {
  type        = bool
  default     = false
  description = <<-EOT
    [EXPERIMENTAL] Create Cost Management exports with CXM's preferred configuration.

    Set to false (default) if exports already exist and you only need read access.
    Set to true to create optimized exports for CXM analysis.

    Note: Requires billing_export_create_storage_account = true.

    WARNING: This feature is experimental. The Azure Cost Management export API
    may change, and FOCUS format support varies by billing account type.
    For production use, we recommend creating exports manually via Azure Portal.
  EOT
}

variable "billing_export_format" {
  type        = string
  default     = "focus"
  description = <<-EOT
    Format of the cost export to create (only used when billing_export_create_cost_exports = true):

    - "focus" (default): FOCUS format - FinOps Open Cost and Usage Specification
      Standardized cross-cloud format with Parquet output and Snappy compression.
      Includes both actual and amortized costs in one export.

    - "legacy": Legacy Azure format using azurerm provider
      Creates ActualCost or AmortizedCost exports (set via billing_export_type).
  EOT

  validation {
    condition     = contains(["focus", "legacy"], var.billing_export_format)
    error_message = "billing_export_format must be 'focus' or 'legacy'."
  }
}

variable "billing_export_location" {
  type        = string
  default     = "westeurope"
  description = <<-EOT
    Azure region for the new billing export storage account.
    Only used when billing_export_create_storage_account = true.
  EOT
}

variable "billing_export_focus_path" {
  type        = string
  default     = ""
  description = <<-EOT
    Glob path to the existing FOCUS cost-export parquet files, echoed back in the
    onboarding output as azure_focus_path so CXM knows where to read cost data.

    Required (for the common existing-export case) when enable_billing_export_access = true.
    Format: az://<container>/<root-folder>/<export-name>/**/*.parquet
    Example: az://cost-exports/daily/cxm-daily-export-focus/**/*.parquet

    Leave empty only when billing_export_create_cost_exports = true, in which case the
    path is derived from the export this module creates.
  EOT
}

# ==============================================================================
# ACTIVITY LOG STORAGE CONFIGURATION
# ==============================================================================

variable "activity_log_storage_account_name" {
  type        = string
  default     = ""
  description = <<-EOT
    Name of the storage account containing Activity Logs.

    Required when enable_activity_log_access = true.
    This should be an existing storage account where activity logs are sent.
  EOT
}

variable "activity_log_storage_resource_group" {
  type        = string
  default     = ""
  description = <<-EOT
    Resource group of the activity log storage account.

    Required when enable_activity_log_access = true.
  EOT
}

# ==============================================================================
# NAMING & TAGS
# ==============================================================================

variable "prefix" {
  type        = string
  default     = "cxm"
  description = <<-EOT
    Prefix for all created resource names.
    Used to easily identify CXM-related resources in your Azure tenant.
  EOT
}

variable "application_name" {
  type        = string
  default     = "cxm-asset-crawler"
  description = <<-EOT
    Display name for the Azure AD Application.
    This name appears in Azure Portal under App Registrations.
  EOT
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = <<-EOT
    Tags to apply to all created resources.
    Useful for cost allocation, governance, and resource organization.

    Example: { "environment" = "production", "managed-by" = "terraform" }
  EOT
}

# ==============================================================================
# DIRECTORY READER ROLE
# ==============================================================================

variable "enable_directory_reader" {
  type        = bool
  default     = true
  description = <<-EOT
    Enable Directory Reader role for the Service Principal.

    When enabled:
    - CXM can read Users, Groups, and Service Principals from Microsoft Graph API
    - Required for complete identity mapping in cost analysis
    - Helps attribute resource ownership and usage to specific teams/users

    Note: Assigning this role requires Azure AD administrative privileges.
    If you don't have these privileges, set this to false and assign manually.
  EOT
}
