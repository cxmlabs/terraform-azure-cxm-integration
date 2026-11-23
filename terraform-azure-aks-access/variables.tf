# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "service_principal_id" {
  type        = string
  description = <<-EOT
    The Object ID of the CXM Service Principal.
    This is the service_principal_id output of the root module.
  EOT
}

# ==============================================================================
# SCOPE CONFIGURATION
# ==============================================================================

variable "subscription_ids" {
  type        = list(string)
  default     = []
  description = <<-EOT
    The subscription IDs that get the role. Has no effect when use_management_group = true.
    The root module passes the subscriptions of the integration.
  EOT
}

variable "use_management_group" {
  type        = bool
  default     = false
  description = <<-EOT
    Make the role assignable at the management group, and assign it on each
    subscription of the management group that is in the state Enabled. Azure cannot assign a custom role
    with data actions at a management-group scope.
  EOT
}

variable "subscription_exclusions" {
  type        = list(string)
  default     = []
  description = <<-EOT
    The subscription IDs that get no assignment when use_management_group = true.
    Use it for the subscriptions that hold clusters without Entra ID.
  EOT
}

variable "management_group_id" {
  type        = string
  default     = ""
  description = "(Required when use_management_group = true) The ID of the management group."
}
