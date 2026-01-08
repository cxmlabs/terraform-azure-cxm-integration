# ==============================================================================
# AUTHENTICATION METHOD
# ==============================================================================

variable "authentication_method" {
  type        = string
  default     = "client_secret"
  description = <<-EOT
    Authentication method for CXM to access your Azure tenant.

    Options:
    - "client_secret": (Default) Creates a client secret (password) for the Azure AD Application.
      Simple to set up. The secret will be output and must be provided to CXM during onboarding.
      The secret is stored in Azure AD and must be securely transmitted to CXM.

    - "federated_credential": Creates a federated credential that trusts CXM's AWS workload identity.
      More secure as no secrets are stored or transmitted. CXM's AWS IAM role is trusted directly.
      Requires cxm_aws_account_id and cxm_aws_role_arn to be provided.
      Note: CXM backend must support this authentication method.
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
    The AWS Account ID of CXM's SaaS platform. Used to establish trust
    between your Azure AD Application and CXM's AWS workload.
    Provided by CXM during onboarding.
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
    Provided by CXM during onboarding.
    Example: "arn:aws:sts::123456789012:assumed-role/cxm-azure-crawler/*"
  EOT
}

# ==============================================================================
# APPLICATION CONFIGURATION
# ==============================================================================

variable "application_name" {
  type        = string
  default     = "cxm-asset-crawler"
  description = <<-EOT
    Display name for the Azure AD Application.
    This name will be visible in the Azure Portal under App Registrations.
  EOT
}

variable "application_owners" {
  type        = list(string)
  default     = []
  description = <<-EOT
    List of Azure AD Object IDs to set as owners of the Application and Service Principal.
    If empty, defaults to the current user running Terraform.
    Owners can manage the application credentials and settings.
  EOT
}

variable "enable_directory_reader" {
  type        = bool
  default     = true
  description = <<-EOT
    Enable Directory Reader role for this Service Principal.
    Allows CXM to read Users, Groups, and Service Principals from Microsoft Graph API.
    Required for complete identity mapping in cost analysis and resource ownership attribution.

    Note: Assigning this role requires Azure AD administrative privileges.
    If you don't have these privileges, set this to false and assign the role manually.
  EOT
}

# ==============================================================================
# CLIENT SECRET CONFIGURATION
# ==============================================================================

variable "client_secret_end_date" {
  type        = string
  default     = "2099-12-31T23:59:59Z"
  description = <<-EOT
    (Only used when authentication_method = "client_secret")
    Expiration date for the client secret in RFC3339 format.
    Default is set far in the future to avoid rotation issues.
    For security-conscious environments, consider a shorter duration and implement rotation.
  EOT
}

# ==============================================================================
# MODULE BEHAVIOR
# ==============================================================================

variable "dry_run" {
  type        = bool
  default     = false
  description = <<-EOT
    When true, no resources are created by this module.
    Useful when you want to use an existing Azure AD Application and only need
    to pass through the provided values without creating new resources.
  EOT
}
