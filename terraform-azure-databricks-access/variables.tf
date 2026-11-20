# ==============================================================================
# REQUIRED VARIABLES
# ==============================================================================

variable "service_principal_application_id" {
  type        = string
  description = <<-EOT
    The Application (Client) ID of the CXM Service Principal.
    This is the client_id output of the root module, or the client ID of an existing CXM App Registration.
  EOT
}

# ==============================================================================
# OPTIONAL VARIABLES
# ==============================================================================

variable "system_schemas" {
  type        = list(string)
  default     = ["billing", "compute", "lakeflow", "query", "access"]
  description = "System schemas that CXM reads. CXM gets USE_SCHEMA and SELECT on each one. Remove query and access to exclude query history and audit events."
}

variable "warehouse_serverless" {
  type        = bool
  default     = true
  description = "Use serverless compute for the CXM SQL warehouse. Set false where serverless SQL is not available."
}
