# terraform-azure-cxm-integration Implementation Plan

## Overview

Create a new Terraform module equivalent to `terraform-aws-cxm-integration` for Microsoft Azure, enabling CXM customers to connect their Azure cloud as a datasource for the FinOps Cloud SaaS.

**Goal:** Provide read-only access to Azure infrastructure for cost analysis, asset discovery, and activity monitoring.

**Reference repositories:**
- AWS reference: `terraform-aws-cxm-integration/`
- Legacy Azure modules: `onboarding/modules/terraform-azure-*`

---

## Module Structure

```
terraform-azure-cxm-integration/
├── main.tf                                    # Root orchestrator
├── variables.tf                               # Main variables
├── outputs.tf                                 # Main outputs
├── locals.tf                                  # Feature flags & computed values
├── provider.tf                                # Provider requirements
├── README.md                                  # Documentation
├── media/
│   └── logo.png                               # CXM logo for App Registration
│
├── terraform-azure-service-principal/         # Identity module
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
│
├── terraform-azure-subscription-enablement/   # Asset discovery module
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
│
├── terraform-azure-billing-export/            # Cost export access module
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
│
└── terraform-azure-activity-log/              # Activity log access module
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── versions.tf
```

---

## Provider Requirements

```hcl
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }
}
```

---

## Tasks

### Phase 1: Project Setup & Service Principal Module

#### Task 1.1: Initialize Repository Structure
- [ ] Create directory structure as defined above
- [ ] Copy `media/logo.png` from `onboarding/modules/terraform-azure-ad-application/media/`
- [ ] Create root `provider.tf` with version requirements
- [ ] Create `.gitignore` file
- [ ] Create initial `README.md` with basic structure

#### Task 1.2: Implement `terraform-azure-service-principal` Module

This module creates the Azure AD Application and Service Principal used by CXM.

**Resources to create:**
- [ ] `azuread_application` - App Registration with CXM branding
- [ ] `azuread_service_principal` - Service Principal for the app
- [ ] `azuread_application_password` - Client secret (conditional on auth method)
- [ ] `azuread_application_federated_identity_credential` - Federated credential (conditional on auth method)
- [ ] `azuread_directory_role` - Directory Readers role reference
- [ ] `azuread_directory_role_assignment` - Assign Directory Reader (optional)
- [ ] `time_sleep` - Wait for AAD propagation (60s)

**Variables to implement:**
```hcl
variable "authentication_method" {
  type        = string
  default     = "client_secret"
  description = <<-EOT
    Authentication method for CXM to access your Azure tenant.

    Options:
    - "client_secret": (Default) Creates a client secret (password) for the Azure AD Application.
      Simple to set up, but requires secure storage of the secret.
      The secret will be output and must be provided to CXM during onboarding.

    - "federated_credential": Creates a federated credential that trusts CXM's AWS workload identity.
      More secure as no secrets are stored in your tenant. CXM's AWS IAM role is trusted directly.
      Requires CXM to provide their AWS account ID and IAM role ARN.
  EOT
}

variable "cxm_aws_account_id" {
  type        = string
  default     = null
  description = <<-EOT
    (Required when authentication_method = "federated_credential")
    The AWS Account ID of CXM's SaaS platform. Used to establish trust
    between your Azure AD Application and CXM's AWS workload.
    Provided by CXM during onboarding.
  EOT
}

variable "cxm_aws_role_arn" {
  type        = string
  default     = null
  description = <<-EOT
    (Required when authentication_method = "federated_credential")
    The ARN of CXM's AWS IAM Role that will access your Azure resources.
    Only this specific AWS role will be able to authenticate.
    Provided by CXM during onboarding.
    Example: arn:aws:iam::123456789012:role/cxm-azure-crawler
  EOT
}

variable "application_name" {
  type        = string
  default     = "cxm-asset-crawler"
  description = "Display name for the Azure AD Application"
}

variable "application_owners" {
  type        = list(string)
  default     = []
  description = "List of Azure AD Object IDs to set as owners. Defaults to current user."
}

variable "enable_directory_reader" {
  type        = bool
  default     = true
  description = <<-EOT
    Enable Directory Reader role for this principal.
    Allows CXM to read Users/Groups/Principals from Microsoft Graph API.
    Required for complete identity mapping in cost analysis.
  EOT
}

variable "client_secret_end_date" {
  type        = string
  default     = "2099-12-31T23:59:59Z"
  description = "(Only for client_secret auth) Expiration date for the client secret in RFC3339 format."
}

variable "dry_run" {
  type        = bool
  default     = false
  description = "When true, no resources are created. Useful for planning with existing resources."
}
```

**Outputs:**
- [ ] `client_id` - Application (client) ID
- [ ] `object_id` - Application object ID
- [ ] `service_principal_id` - Service Principal object ID
- [ ] `client_secret` - Client secret value (sensitive, null if federated)
- [ ] `authentication_method` - Which auth method was used
- [ ] `created` - Boolean indicating if resources were created

**Validation:**
- [ ] Add validation to require `cxm_aws_account_id` and `cxm_aws_role_arn` when `authentication_method = "federated_credential"`

---

### Phase 2: Subscription Enablement Module (Asset Discovery)

#### Task 2.1: Implement `terraform-azure-subscription-enablement` Module

This module grants read access to Azure subscriptions for asset discovery.

**Resources to create:**
- [ ] `azurerm_role_assignment` - Reader role (per subscription or management group)
- [ ] `azurerm_role_assignment` - Monitoring Reader role (per subscription or management group)
- [ ] `azurerm_role_assignment` - Key Vault Reader role (per subscription or management group)

**Data sources:**
- [ ] `azurerm_subscription.primary` - Current subscription
- [ ] `azurerm_subscriptions.available` - All available subscriptions
- [ ] `azurerm_management_group` - Management group (conditional)

**Variables to implement:**
```hcl
variable "service_principal_id" {
  type        = string
  description = "The Service Principal Object ID to grant access to"
}

variable "all_subscriptions" {
  type        = bool
  default     = false
  description = <<-EOT
    Grant read access to ALL enabled subscriptions in the tenant.
    When true, overrides the subscription_ids variable.
    Subscriptions in subscription_exclusions will be skipped.
  EOT
}

variable "subscription_ids" {
  type        = list(string)
  default     = []
  description = <<-EOT
    List of specific subscription IDs to grant read access to.
    If empty and all_subscriptions is false, defaults to the current subscription.
  EOT
}

variable "subscription_exclusions" {
  type        = list(string)
  default     = []
  description = "List of subscription IDs to exclude when using all_subscriptions = true"
}

variable "use_management_group" {
  type        = bool
  default     = false
  description = <<-EOT
    Grant access at the Management Group level instead of individual subscriptions.
    More efficient for large organizations as permissions inherit to all child subscriptions.
    Requires management_group_id to be set.
  EOT
}

variable "management_group_id" {
  type        = string
  default     = ""
  description = <<-EOT
    (Required when use_management_group = true)
    The ID of the Management Group to grant access to.
    All child subscriptions will inherit the permissions.
  EOT
}
```

**Outputs:**
- [ ] `subscription_ids` - List of subscriptions with access granted
- [ ] `management_group_id` - Management group ID if used

**Notes:**
- Management Group role assignments only need Reader and Key Vault Reader (Monitoring Reader inherits)
- Handle the case where azurerm provider 4.x may have different attribute names

---

### Phase 3: Billing Export Module (Cost Data)

#### Task 3.1: Implement `terraform-azure-billing-export` Module

This module provides access to Azure Cost Management exports (equivalent to AWS CUR).

**Primary Use Case:** Grant read access to an **existing** storage account where cost exports are already configured. Cost exports are typically already set up by the customer or their FinOps team.

**Secondary Use Case:** Optionally create new cost exports with CXM's preferred format (hourly granularity, Parquet format) for optimal analysis.

#### Azure Cost Management Export Options

| Setting | Options | CXM Preferred |
|---------|---------|---------------|
| **Type** | ActualCost, AmortizedCost, Usage | All (read any existing) |
| **Time Frame** | MonthToDate, BillingMonthToDate, TheLastMonth, etc. | MonthToDate |
| **Granularity** | Daily, Monthly | **Daily** (or Hourly via API) |
| **Format** | CSV | CSV (Parquet not yet supported in TF) |
| **Recurrence** | Daily, Weekly, Monthly | **Daily** |

> **Note:** Azure Cost Management exports via Terraform (`azurerm_subscription_cost_management_export`) currently only support CSV format. Parquet format requires Azure Portal or API configuration.

**Resources to create (for granting access to EXISTING storage):**
- [ ] `azurerm_role_definition` - Custom role for storage read access
- [ ] `azurerm_role_assignment` - Assign custom role to service principal
- [ ] `time_sleep` - Wait for role propagation

**Resources to create (when OPTIONALLY creating new exports):**
- [ ] `azurerm_resource_group` - Resource group for storage account (if new storage)
- [ ] `azurerm_storage_account` - Storage account for exports (if new storage)
- [ ] `azurerm_storage_container` - Container for export data (if new storage)
- [ ] `azurerm_subscription_cost_management_export` - Cost export per subscription (optional)

**Data sources:**
- [ ] `azurerm_storage_account` - Existing storage account
- [ ] `azurerm_subscription.primary` - Current subscription
- [ ] `azurerm_subscriptions.available` - All subscriptions

**Variables to implement:**
```hcl
variable "service_principal_id" {
  type        = string
  description = "The Service Principal Object ID to grant storage access to"
}

# ============================================================================
# STORAGE ACCOUNT CONFIGURATION
# ============================================================================

variable "storage_account_name" {
  type        = string
  description = <<-EOT
    Name of the storage account containing cost exports.
    This is typically an existing storage account where exports are already configured.
  EOT
}

variable "storage_account_resource_group" {
  type        = string
  description = "Resource group of the storage account"
}

variable "create_storage_account" {
  type        = bool
  default     = false
  description = <<-EOT
    Create a new storage account instead of using an existing one.
    Only set to true if no cost export storage exists yet.
  EOT
}

variable "location" {
  type        = string
  default     = "westeurope"
  description = "Azure region for new storage account (only when create_storage_account = true)"
}

# ============================================================================
# COST EXPORT CONFIGURATION (Optional)
# ============================================================================

variable "create_cost_exports" {
  type        = bool
  default     = false
  description = <<-EOT
    Create new Cost Management exports with CXM's preferred configuration.
    Set to false (default) if exports already exist and you only need read access.
    Set to true to create optimized exports for CXM analysis.
  EOT
}

variable "export_subscriptions" {
  type        = list(string)
  default     = []
  description = <<-EOT
    (Only when create_cost_exports = true)
    List of subscription IDs to create cost exports for.
    If empty, creates exports for all enabled subscriptions.
  EOT
}

variable "export_type" {
  type        = string
  default     = "ActualCost"
  description = <<-EOT
    (Only when create_cost_exports = true)
    Type of cost data to export:
    - "ActualCost": Actual billed costs
    - "AmortizedCost": Costs with reservation amortization
    - "Usage": Usage data only
  EOT

  validation {
    condition     = contains(["ActualCost", "AmortizedCost", "Usage"], var.export_type)
    error_message = "export_type must be ActualCost, AmortizedCost, or Usage."
  }
}

variable "export_recurrence" {
  type        = string
  default     = "Daily"
  description = <<-EOT
    (Only when create_cost_exports = true)
    How often to run the export: Daily, Weekly, Monthly
  EOT
}

variable "root_folder_path" {
  type        = string
  default     = "/cxm-cost-exports"
  description = "Root folder path in the storage container for cost export data"
}

# ============================================================================
# COMMON CONFIGURATION
# ============================================================================

variable "prefix" {
  type        = string
  default     = "cxm"
  description = "Prefix for resource naming"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to created resources"
}

variable "wait_time" {
  type        = string
  default     = "30s"
  description = "Time to wait for Azure resource propagation"
}
```

**Custom Role Permissions:**
```hcl
permissions {
  actions = [
    "Microsoft.Resources/subscriptions/resourceGroups/read",
    "Microsoft.Storage/storageAccounts/read",
    "Microsoft.Storage/storageAccounts/blobServices/containers/read",
    "Microsoft.Storage/storageAccounts/listkeys/action",
    "Microsoft.EventGrid/eventSubscriptions/read",
    # Read cost management exports configuration
    "Microsoft.CostManagement/exports/read"
  ]
  data_actions = [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
  ]
}
```

**Outputs:**
- [ ] `storage_account_name` - Name of storage account
- [ ] `storage_account_resource_group` - Resource group name
- [ ] `exports_created` - Boolean, whether exports were created
- [ ] `export_subscription_ids` - Subscriptions with cost exports (if created)

---

### Phase 4: Activity Log Module

#### Task 4.1: Implement `terraform-azure-activity-log` Module

This module provides access to Azure Activity Logs (equivalent to AWS CloudTrail).

**Resources to create (when creating new storage):**
- [ ] `azurerm_resource_group` - Resource group for storage account
- [ ] `azurerm_storage_account` - Storage account for logs

**Resources to create (always):**
- [ ] `azurerm_monitor_diagnostic_setting` - Diagnostic settings per subscription
- [ ] `azurerm_role_definition` - Custom role for storage access
- [ ] `azurerm_role_assignment` - Assign custom role to service principal
- [ ] `time_sleep` - Wait for role propagation

**Data sources:**
- [ ] `azurerm_storage_account` - Existing storage account (conditional)
- [ ] `azurerm_subscription.primary` - Current subscription
- [ ] `azurerm_subscriptions.available` - All subscriptions

**Variables:** (Similar to billing-export module, plus:)
```hcl
variable "diagnostic_settings_name" {
  type        = string
  default     = "cxm-activity-logs"
  description = "Name for the diagnostic settings resource"
}

variable "log_categories" {
  type        = list(string)
  default     = ["Administrative", "Recommendation"]
  description = <<-EOT
    Activity Log categories to capture. Available categories:
    - Administrative: Resource management operations
    - Security: Security Center alerts
    - ServiceHealth: Service health incidents
    - Alert: Azure alerts
    - Recommendation: Azure Advisor recommendations
    - Policy: Azure Policy operations
    - Autoscale: Autoscale operations
    - ResourceHealth: Resource health status
  EOT
}
```

**Outputs:**
- [ ] `storage_account_name` - Name of storage account
- [ ] `storage_account_resource_group` - Resource group name
- [ ] `diagnostic_settings_name` - Name of diagnostic settings
- [ ] `subscription_ids` - Subscriptions with diagnostic settings configured

---

### Phase 5: Root Module Integration

#### Task 5.1: Implement Root Module

Orchestrates all sub-modules with feature flags.

**File: `main.tf`**
- [ ] Call `terraform-azure-service-principal` module
- [ ] Call `terraform-azure-subscription-enablement` module (conditional)
- [ ] Call `terraform-azure-billing-export` module (conditional)
- [ ] Call `terraform-azure-activity-log` module (conditional)
- [ ] Wire outputs between modules

**File: `variables.tf`**
```hcl
# ============================================================================
# REQUIRED VARIABLES
# ============================================================================

# (None strictly required - module works with sensible defaults)

# ============================================================================
# AUTHENTICATION CONFIGURATION
# ============================================================================

variable "authentication_method" {
  type        = string
  default     = "client_secret"
  description = <<-EOT
    Authentication method for CXM to access your Azure tenant.

    Options:
    - "client_secret": (Default) Creates a client secret (password) for the Azure AD Application.
      Simple to set up. The secret will be output and must be provided to CXM during onboarding.

    - "federated_credential": Creates a federated credential trusting CXM's AWS workload identity.
      More secure - no secrets stored in your tenant. Requires cxm_aws_account_id and cxm_aws_role_arn.
  EOT
}

variable "cxm_aws_account_id" {
  type        = string
  default     = null
  description = "(Required for federated_credential auth) CXM's AWS Account ID. Provided by CXM."
}

variable "cxm_aws_role_arn" {
  type        = string
  default     = null
  description = "(Required for federated_credential auth) CXM's AWS IAM Role ARN. Provided by CXM."
}

# ============================================================================
# FEATURE TOGGLES
# ============================================================================

variable "enable_asset_discovery" {
  type        = bool
  default     = true
  description = <<-EOT
    Enable asset discovery permissions (Reader roles on subscriptions).
    Strongly recommended - required for infrastructure analysis and recommendations.
  EOT
}

variable "enable_billing_export" {
  type        = bool
  default     = true
  description = <<-EOT
    Enable access to Cost Management exports.
    Required for cost analysis and FinOps recommendations.
  EOT
}

variable "enable_activity_logs" {
  type        = bool
  default     = true
  description = <<-EOT
    Enable access to Activity Logs.
    Recommended for change tracking and security analysis.
  EOT
}

# ============================================================================
# SCOPE CONFIGURATION
# ============================================================================

variable "use_management_group" {
  type        = bool
  default     = false
  description = "Grant access at Management Group level (inherits to all child subscriptions)"
}

variable "management_group_id" {
  type        = string
  default     = ""
  description = "(Required when use_management_group = true) Management Group ID"
}

variable "all_subscriptions" {
  type        = bool
  default     = false
  description = "Grant access to all enabled subscriptions in the tenant"
}

variable "subscription_ids" {
  type        = list(string)
  default     = []
  description = "Specific subscription IDs to enable (defaults to current subscription if empty)"
}

variable "subscription_exclusions" {
  type        = list(string)
  default     = []
  description = "Subscription IDs to exclude when using all_subscriptions"
}

# ============================================================================
# EXISTING RESOURCES (Optional)
# ============================================================================

variable "use_existing_ad_application" {
  type        = bool
  default     = false
  description = "Use an existing Azure AD Application instead of creating one"
}

variable "existing_client_id" {
  type        = string
  default     = ""
  description = "(Required when use_existing_ad_application = true) Existing App client ID"
}

variable "existing_client_secret" {
  type        = string
  default     = ""
  sensitive   = true
  description = "(Required when use_existing_ad_application = true) Existing App client secret"
}

variable "existing_service_principal_id" {
  type        = string
  default     = ""
  description = "(Required when use_existing_ad_application = true) Existing Service Principal object ID"
}

variable "use_existing_billing_storage" {
  type        = bool
  default     = false
  description = "Use existing storage account for billing exports"
}

variable "use_existing_activity_log_storage" {
  type        = bool
  default     = false
  description = "Use existing storage account for activity logs"
}

# ============================================================================
# NAMING & TAGS
# ============================================================================

variable "prefix" {
  type        = string
  default     = "cxm"
  description = "Prefix for all created resource names"
}

variable "application_name" {
  type        = string
  default     = "cxm-asset-crawler"
  description = "Display name for the Azure AD Application"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all created resources"
}

# ============================================================================
# REGIONAL CONFIGURATION
# ============================================================================

variable "location" {
  type        = string
  default     = "westeurope"
  description = "Azure region for storage accounts"
}
```

**File: `outputs.tf`**
```hcl
# ============================================================================
# ONBOARDING VALUES - Provide these to CXM
# ============================================================================

output "cxm_onboarding_values" {
  description = <<-EOT
    Values to provide to CXM during onboarding.
    Copy these values to the CXM onboarding form or API.
  EOT
  sensitive   = true
  value = {
    tenant_id            = data.azurerm_subscription.primary.tenant_id
    client_id            = local.client_id
    authentication_method = var.authentication_method
    # Only present when using client_secret authentication:
    client_secret        = var.authentication_method == "client_secret" ? local.client_secret : null
    subscription_ids     = local.enabled_subscription_ids
  }
}

# ============================================================================
# INDIVIDUAL OUTPUTS
# ============================================================================

output "tenant_id" {
  description = "Azure AD Tenant ID"
  value       = data.azurerm_subscription.primary.tenant_id
}

output "client_id" {
  description = "Azure AD Application (Client) ID"
  value       = local.client_id
}

output "service_principal_id" {
  description = "Service Principal Object ID"
  value       = local.service_principal_id
}

output "client_secret" {
  description = "Client Secret (only when using client_secret authentication)"
  sensitive   = true
  value       = var.authentication_method == "client_secret" ? local.client_secret : null
}

output "authentication_method" {
  description = "Authentication method configured"
  value       = var.authentication_method
}

output "subscription_ids" {
  description = "List of Azure subscription IDs with CXM access"
  value       = local.enabled_subscription_ids
}

output "billing_storage_account" {
  description = "Storage account name for billing exports (if enabled)"
  value       = var.enable_billing_export ? module.billing_export[0].storage_account_name : null
}

output "activity_log_storage_account" {
  description = "Storage account name for activity logs (if enabled)"
  value       = var.enable_activity_logs ? module.activity_log[0].storage_account_name : null
}
```

**File: `locals.tf`**
- [ ] Feature flag computations
- [ ] Subscription list resolution
- [ ] Conditional resource references

---

### Phase 6: Documentation & Testing

#### Task 6.1: Documentation
- [ ] Write comprehensive `README.md` with:
  - Quick start example
  - Authentication methods explanation
  - All variables documentation
  - Outputs explanation
  - Examples for common scenarios
- [ ] Add inline documentation in all variable descriptions
- [ ] Create `examples/` directory with:
  - `basic/` - Minimal setup with client_secret
  - `management-group/` - Management group level access
  - `federated-credentials/` - AWS federated auth
  - `existing-resources/` - Using existing AD app and storage

#### Task 6.2: Testing
- [ ] Test with new Azure AD Application + client secret
- [ ] Test with existing Azure AD Application
- [ ] Test with Management Group level access
- [ ] Test with specific subscription list
- [ ] Test with all_subscriptions = true
- [ ] Test federated credentials (requires CXM backend support)
- [ ] Verify all outputs are correct
- [ ] Test `terraform plan` and `terraform apply`
- [ ] Test `terraform destroy` cleans up properly

---

## Migration Notes from Legacy Modules

### Breaking Changes from Old Modules

1. **No local JSON file output** - Use Terraform outputs instead
2. **Provider version upgrade** - azurerm 3.x -> 4.x, azuread 2.x -> 3.x
3. **Unified module** - Single root module instead of 4 separate modules
4. **New authentication option** - Federated credentials available

### azurerm 4.x Migration Notes

Check for these common changes:
- [ ] `azurerm_storage_account`: `enable_https_traffic_only` -> `https_traffic_only_enabled`
- [ ] `azurerm_storage_account`: `allow_nested_items_to_be_public` -> `allow_nested_items_to_be_public` (verify)
- [ ] `azurerm_storage_account`: `queue_properties` block changes
- [ ] Resource attribute renames and removals

### azuread 3.x Migration Notes

Check for these common changes:
- [ ] `azuread_application`: `web` block structure
- [ ] `azuread_application_password`: `application_id` -> `application_object_id` or similar
- [ ] `azuread_directory_role_assignment`: verify attribute names
- [ ] New federated identity credential resource syntax

---

## Timeline Estimate

| Phase | Tasks | Complexity |
|-------|-------|------------|
| Phase 1 | Setup + Service Principal | Medium |
| Phase 2 | Subscription Enablement | Low |
| Phase 3 | Billing Export | Medium |
| Phase 4 | Activity Log | Medium |
| Phase 5 | Root Module | Medium |
| Phase 6 | Docs & Testing | Medium |

---

## Decisions Made

| Question | Decision |
|----------|----------|
| **Storage accounts** | **Separated** - Billing exports and activity logs use separate storage accounts |
| **Cost exports** | Exports likely already exist. Grant read access to existing storage. Optionally create exports with CXM-preferred format (hourly, Parquet) |
| **AWS credentials** | Provided via variables (`cxm_aws_account_id`, `cxm_aws_role_arn`) |
| **Federated credentials backend** | **Not ready** - Requires separate implementation task (see Phase 7) |

---

## Checklist Summary

- [ ] **Phase 1**: Project setup & service principal module
- [ ] **Phase 2**: Subscription enablement module
- [ ] **Phase 3**: Billing export module
- [ ] **Phase 4**: Activity log module
- [ ] **Phase 5**: Root module integration
- [ ] **Phase 6**: Documentation & testing
- [ ] **Phase 7**: CXM backend - Azure federated credentials support (separate task)

---

## Phase 7: CXM Backend - Azure Federated Credentials Support

> **Note:** This phase is a separate task for the CXM backend team, not part of the Terraform module implementation.

### Overview

To support the `federated_credential` authentication method, CXM's AWS-based backend must be updated to authenticate to Azure using AWS OIDC tokens exchanged for Azure AD tokens.

### How It Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CXM SaaS (AWS)                                  │
│                                                                         │
│  1. CXM workload (Lambda/ECS) calls AWS STS to get an OIDC token       │
│     - Uses web identity token from the execution environment            │
│                                                                         │
│  2. CXM calls Azure AD token endpoint with:                            │
│     - client_id: Customer's Azure AD Application ID                     │
│     - client_assertion_type: urn:ietf:params:oauth:                    │
│                              client-assertion-type:jwt-bearer           │
│     - client_assertion: The AWS OIDC token                             │
│     - grant_type: client_credentials                                    │
│     - scope: https://management.azure.com/.default                     │
│                                                                         │
│  3. Azure AD validates the token against the federated credential:     │
│     - Issuer: https://sts.amazonaws.com                                │
│     - Subject: arn:aws:sts::CXM_ACCOUNT:assumed-role/CXM_ROLE/...     │
│     - Audience: api://AzureADTokenExchange (or custom)                 │
│                                                                         │
│  4. Azure AD returns an access token for Azure Resource Manager        │
│                                                                         │
│  5. CXM uses the access token to call Azure APIs                       │
└─────────────────────────────────────────────────────────────────────────┘
```

### Implementation Tasks

#### Task 7.1: Research & Design
- [ ] Document the exact OIDC token exchange flow
- [ ] Determine which AWS IAM role(s) will be used for Azure authentication
- [ ] Define the audience value for federated credentials
- [ ] Design credential storage (how to store customer's Azure tenant_id, client_id)

#### Task 7.2: AWS Infrastructure
- [ ] Ensure CXM's crawler IAM role can call `sts:AssumeRoleWithWebIdentity` or get OIDC tokens
- [ ] Configure the IAM role trust policy if needed
- [ ] Document the exact role ARN to provide to customers

#### Task 7.3: Backend Code Implementation
- [ ] Implement Azure AD token acquisition using AWS OIDC token
- [ ] Handle token caching and refresh
- [ ] Integrate with existing Azure crawler code
- [ ] Add configuration for authentication method per tenant (client_secret vs federated)

#### Task 7.4: Testing
- [ ] Test with a real Azure tenant configured with federated credentials
- [ ] Verify token exchange works from Lambda/ECS environments
- [ ] Test error handling (invalid credentials, expired tokens, etc.)

### Azure Federated Credential Configuration

The Terraform module will create this configuration in the customer's Azure AD:

```hcl
resource "azuread_application_federated_identity_credential" "cxm_aws" {
  application_id = azuread_application.cxm.id
  display_name   = "CXM AWS Workload Identity"
  description    = "Trust CXM's AWS workload to authenticate without secrets"

  # AWS STS as the OIDC issuer
  issuer         = "https://sts.amazonaws.com"

  # The specific AWS IAM role that can authenticate
  # Format: arn:aws:sts::ACCOUNT:assumed-role/ROLE_NAME/SESSION_NAME
  subject        = var.cxm_aws_role_arn

  # Audience - Azure AD expects this value
  audiences      = ["api://AzureADTokenExchange"]
}
```

### Values CXM Must Provide to Customers

For federated credential setup, CXM must provide:

| Value | Description | Example |
|-------|-------------|---------|
| `cxm_aws_account_id` | CXM's AWS Account ID | `123456789012` |
| `cxm_aws_role_arn` | Full ARN of the IAM role | `arn:aws:sts::123456789012:assumed-role/cxm-azure-crawler/*` |

### References

- [Azure AD Workload Identity Federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)
- [AWS as Identity Provider for Azure](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-aws)
- [azuread_application_federated_identity_credential](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential)
