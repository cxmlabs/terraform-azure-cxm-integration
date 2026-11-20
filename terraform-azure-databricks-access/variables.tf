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

variable "service_principal_display_name" {
  type        = string
  default     = "cxm-asset-crawler"
  description = "Display name of the CXM Service Principal in the Databricks workspace."
}

variable "system_schemas" {
  type        = list(string)
  default     = ["billing", "compute", "lakeflow", "query", "access"]
  description = "System schemas that CXM reads. CXM gets USE_SCHEMA and SELECT on each one."
}

variable "enable_system_schemas" {
  type        = bool
  default     = false
  description = <<-EOT
    Enable the system schemas of var.system_schemas in the metastore (billing is always enabled).
    Requires a metastore admin. Keep false when the schemas are already enabled.
  EOT
}

variable "warehouse_name" {
  type        = string
  default     = "cxm"
  description = "Name of the SQL warehouse that CXM uses to read the system tables."
}

variable "warehouse_cluster_size" {
  type        = string
  default     = "2X-Small"
  description = "Cluster size of the CXM SQL warehouse."
}

variable "warehouse_auto_stop_mins" {
  type        = number
  default     = 10
  description = "Idle minutes before the CXM SQL warehouse stops."
}

variable "warehouse_serverless" {
  type        = bool
  default     = true
  description = "Use serverless compute for the CXM SQL warehouse. Set false where serverless SQL is not available."
}
