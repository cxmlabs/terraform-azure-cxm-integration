# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "service_principal_id" {
  type        = string
  description = <<-EOT
    The Object ID of the Service Principal to grant storage access to.
    This is the service_principal_id output from the terraform-azure-service-principal module.
  EOT
}

variable "storage_account_name" {
  type        = string
  description = <<-EOT
    Name of the storage account containing (or to contain) activity logs.

    If create_storage_account = false (default):
      This must be an existing storage account where activity logs are being sent.

    If create_storage_account = true:
      This will be the name for the new storage account.
      Must be 3-24 characters, lowercase letters and numbers only.
      If empty, a name will be auto-generated.
  EOT
  default     = ""
}

variable "storage_account_resource_group" {
  type        = string
  description = <<-EOT
    Resource group containing the storage account.

    If create_storage_account = false (default):
      This must be the resource group of the existing storage account.

    If create_storage_account = true:
      This will be the resource group for the new storage account.
      If empty, a new resource group will be created.
  EOT
  default     = ""
}

# ==============================================================================
# STORAGE ACCOUNT CONFIGURATION
# ==============================================================================

variable "create_storage_account" {
  type        = bool
  default     = false
  description = <<-EOT
    Create a new storage account instead of using an existing one.
    Set to true only if no activity log storage exists yet.

    When true:
    - A new resource group will be created (unless storage_account_resource_group is set)
    - A new storage account will be created
  EOT
}

variable "location" {
  type        = string
  default     = "westeurope"
  description = <<-EOT
    Azure region for the new storage account.
    Only used when create_storage_account = true.
  EOT
}

# ==============================================================================
# DIAGNOSTIC SETTINGS CONFIGURATION (Optional)
# ==============================================================================

variable "create_diagnostic_settings" {
  type        = bool
  default     = false
  description = <<-EOT
    Create diagnostic settings to send activity logs to the storage account.

    Set to false (default) if diagnostic settings already exist.
    Set to true to create new diagnostic settings for the specified subscriptions.

    Note: Activity logs may already be configured by your organization.
    Only enable this if you're sure no diagnostic settings exist.
  EOT
}

variable "diagnostic_subscriptions" {
  type        = list(string)
  default     = []
  description = <<-EOT
    (Only used when create_diagnostic_settings = true)
    List of subscription IDs to create diagnostic settings for.
    If empty, creates diagnostic settings for the current subscription only.
  EOT
}

variable "diagnostic_settings_name" {
  type        = string
  default     = "cxm-activity-logs"
  description = <<-EOT
    Name for the diagnostic settings resources.
    Only used when create_diagnostic_settings = true.
  EOT
}

variable "log_categories" {
  type        = list(string)
  default     = ["Administrative", "Security", "Recommendation", "Policy"]
  description = <<-EOT
    Activity log categories to capture in diagnostic settings.
    Only used when create_diagnostic_settings = true.

    Available categories:
    - Administrative: Resource management operations (create, update, delete)
    - Security: Security Center alerts and recommendations
    - ServiceHealth: Azure service health incidents
    - Alert: Azure Monitor alerts
    - Recommendation: Azure Advisor recommendations
    - Policy: Azure Policy operations
    - Autoscale: Autoscale engine operations
    - ResourceHealth: Resource health status changes
  EOT
}

# ==============================================================================
# COMMON CONFIGURATION
# ==============================================================================

variable "prefix" {
  type        = string
  default     = "cxm"
  description = "Prefix for created resource names"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to created resources"
}

variable "wait_time" {
  type        = string
  default     = "30s"
  description = "Time to wait for Azure role assignment propagation"
}
