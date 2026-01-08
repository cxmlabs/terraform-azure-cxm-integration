# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "service_principal_id" {
  type        = string
  description = <<-EOT
    The Object ID of the Service Principal to grant access to.
    This is the service_principal_id output from the terraform-azure-service-principal module.
  EOT
}

# ==============================================================================
# SCOPE CONFIGURATION
# ==============================================================================

variable "all_subscriptions" {
  type        = bool
  default     = false
  description = <<-EOT
    Grant read access to ALL enabled subscriptions in the tenant.
    When true, overrides the subscription_ids variable.
    Subscriptions listed in subscription_exclusions will be skipped.

    Note: This discovers subscriptions at plan/apply time. New subscriptions
    added later will not automatically get access - you'll need to re-apply.
  EOT
}

variable "subscription_ids" {
  type        = list(string)
  default     = []
  description = <<-EOT
    List of specific subscription IDs to grant read access to.
    If empty and all_subscriptions is false, defaults to the current subscription
    (the one configured in the Azure provider).
  EOT
}

variable "subscription_exclusions" {
  type        = list(string)
  default     = []
  description = <<-EOT
    List of subscription IDs to exclude when using all_subscriptions = true.
    Has no effect when all_subscriptions = false.
  EOT
}

# ==============================================================================
# MANAGEMENT GROUP CONFIGURATION
# ==============================================================================

variable "use_management_group" {
  type        = bool
  default     = false
  description = <<-EOT
    Grant access at the Management Group level instead of individual subscriptions.
    More efficient for large organizations as permissions inherit to all child subscriptions.

    When true:
    - Requires management_group_id to be set
    - The subscription_ids and all_subscriptions variables are ignored
    - Access is granted to the management group and all subscriptions beneath it
  EOT
}

variable "management_group_id" {
  type        = string
  default     = ""
  description = <<-EOT
    (Required when use_management_group = true)
    The ID of the Management Group to grant access to.
    Can be found in Azure Portal > Management Groups, or via Azure CLI:
    az account management-group list

    Example: "00000000-0000-0000-0000-000000000000"
  EOT
}
