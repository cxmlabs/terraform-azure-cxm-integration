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
    Name of the storage account containing (or to contain) cost exports.

    If create_storage_account = false (default):
      This must be an existing storage account where cost exports are already configured.

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
    Set to true only if no cost export storage exists yet.

    When true:
    - A new resource group will be created (unless storage_account_resource_group is set)
    - A new storage account will be created
    - A new storage container will be created
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
# COST EXPORT CONFIGURATION (Optional)
# ==============================================================================

variable "create_cost_exports" {
  type        = bool
  default     = false
  description = <<-EOT
    Create new Cost Management exports with CXM's preferred configuration.

    Set to false (default) if exports already exist and you only need read access.
    Set to true to create optimized exports for CXM analysis.

    Note: Cost exports are typically already configured by FinOps teams.
    Only enable this if you're sure no exports exist for the target subscriptions.
  EOT
}

variable "export_format" {
  type        = string
  default     = "focus"
  description = <<-EOT
    (Only used when create_cost_exports = true)
    Format of the cost export to create:

    - "focus": FOCUS format (recommended) - FinOps Open Cost and Usage Specification
      Standardized cross-cloud format, includes both actual and amortized costs.
      Uses azapi provider to call Azure REST API.

    - "legacy": Legacy Azure format using azurerm provider
      Creates ActualCost or AmortizedCost exports (set via export_type variable).
  EOT

  validation {
    condition     = contains(["focus", "legacy"], var.export_format)
    error_message = "export_format must be 'focus' or 'legacy'."
  }
}

variable "focus_version" {
  type        = string
  default     = "1.0"
  description = <<-EOT
    (Only used when export_format = "focus")
    FOCUS specification version to use:
    - "1.0": Stable version (recommended)
    - "1.0r2": Revision 2
    - "1.0-preview(v1)": Preview version
  EOT
}

variable "export_subscriptions" {
  type        = list(string)
  default     = []
  description = <<-EOT
    (Only used when create_cost_exports = true)
    List of subscription IDs to create cost exports for.
    If empty, creates exports for the current subscription only.
  EOT
}

variable "export_type" {
  type        = string
  default     = "ActualCost"
  description = <<-EOT
    (Only used when create_cost_exports = true)
    Type of cost data to export:
    - "ActualCost": Actual billed costs (default, most common)
    - "AmortizedCost": Costs with reservation/savings plan amortization
    - "Usage": Usage quantity data only (no costs)
  EOT

  validation {
    condition     = contains(["ActualCost", "AmortizedCost", "Usage"], var.export_type)
    error_message = "export_type must be 'ActualCost', 'AmortizedCost', or 'Usage'."
  }
}

variable "export_recurrence" {
  type        = string
  default     = "Daily"
  description = <<-EOT
    (Only used when create_cost_exports = true)
    How often to run the export: Daily, Weekly, or Monthly.
    Daily is recommended for timely cost visibility.
  EOT

  validation {
    condition     = contains(["Daily", "Weekly", "Monthly"], var.export_recurrence)
    error_message = "export_recurrence must be 'Daily', 'Weekly', or 'Monthly'."
  }
}

variable "root_folder_path" {
  type        = string
  default     = "/cxm-cost-exports"
  description = <<-EOT
    Root folder path in the storage container for cost export data.
    Only used when create_cost_exports = true.
  EOT
}

variable "focus_path" {
  type        = string
  default     = ""
  description = <<-EOT
    Glob path to an existing FOCUS export's parquet files
    (az://<container>/<root>/<export>/**/*.parquet), echoed back via the focus_path output.
    Ignored when this module creates the export - the path is then derived from what it creates.
  EOT
}

# ==============================================================================
# COMMON CONFIGURATION
# ==============================================================================

variable "prefix" {
  type        = string
  default     = "cxm"
  description = "Prefix for created resource names (storage account, resource group, etc.)"
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
