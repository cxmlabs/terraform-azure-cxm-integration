# CXM Azure Integration Module

This Terraform module enables CXM (Cloud ex Machina) to access your Microsoft Azure tenant for FinOps analysis, cost optimization, and infrastructure recommendations.

## Overview

The module creates the necessary Azure resources to grant CXM read-only access to:

- **Asset Discovery**: Read access to all Azure resources for infrastructure analysis
- **Cost Data**: Read access to Cost Management exports for cost analysis
- **Activity Logs**: Read access to Activity Logs for change tracking and security analysis

## Quick Start

### Basic Usage (Single Subscription)

```hcl
provider "azurerm" {
  features {}
}

provider "azuread" {}

module "cxm_integration" {
  source = "path/to/terraform-azure-cxm-integration"

  # Authentication (client_secret is the default)
  authentication_method = "client_secret"

  # Enable features
  enable_asset_discovery      = true
  enable_billing_export_access = true
  enable_activity_log_access   = true

  # Storage accounts for cost and activity data (must already exist)
  billing_export_storage_account_name   = "mycompanycostexports"
  billing_export_storage_resource_group = "finops-rg"

  activity_log_storage_account_name   = "mycompanyactivitylogs"
  activity_log_storage_resource_group = "logging-rg"

  tags = {
    environment = "production"
    managed-by  = "terraform"
  }
}

# Output the values needed for CXM onboarding
output "cxm_onboarding" {
  value     = module.cxm_integration.cxm_onboarding_values
  sensitive = true
}
```

### All Subscriptions in Tenant

```hcl
module "cxm_integration" {
  source = "path/to/terraform-azure-cxm-integration"

  # Grant access to all subscriptions
  all_subscriptions = true

  # Optionally exclude specific subscriptions
  subscription_exclusions = [
    "00000000-0000-0000-0000-000000000001",  # Sandbox
    "00000000-0000-0000-0000-000000000002",  # Dev
  ]

  # ... rest of configuration
}
```

### Management Group Level Access

```hcl
module "cxm_integration" {
  source = "path/to/terraform-azure-cxm-integration"

  # Grant access at management group level (inherits to all subscriptions)
  use_management_group = true
  management_group_id  = "00000000-0000-0000-0000-000000000000"

  # ... rest of configuration
}
```

### Federated Credentials (No Secrets)

```hcl
module "cxm_integration" {
  source = "path/to/terraform-azure-cxm-integration"

  # Use federated credentials instead of client secret
  authentication_method = "federated_credential"
  cxm_aws_account_id    = "123456789012"           # Provided by CXM
  cxm_aws_role_arn      = "arn:aws:sts::123456789012:assumed-role/cxm-azure-crawler/*"

  # ... rest of configuration
}
```

## Authentication Methods

### Client Secret (Default)

The traditional authentication method using a client secret (password):

- **Pros**: Simple to set up, widely supported
- **Cons**: Requires secure transmission and storage of the secret

```hcl
authentication_method = "client_secret"
```

The client secret will be output and must be provided to CXM during onboarding.

### Federated Credentials

A more secure method using AWS OIDC federation:

- **Pros**: No secrets stored in your tenant or transmitted
- **Cons**: -

```hcl
authentication_method = "federated_credential"
cxm_aws_account_id    = "123456789012"
cxm_aws_role_arn      = "arn:aws:sts::123456789012:assumed-role/cxm-azure-crawler/*"
```

## Module Structure

```
terraform-azure-cxm-integration/
├── main.tf                                    # Root module orchestration
├── variables.tf                               # Input variables
├── outputs.tf                                 # Output values
├── locals.tf                                  # Local computations
├── provider.tf                                # Provider requirements
├── terraform-azure-service-principal/         # Azure AD identity
├── terraform-azure-subscription-enablement/   # Resource read access
├── terraform-azure-billing-export/            # Cost export access
└── terraform-azure-activity-log/              # Activity log access
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.0 |
| azurerm | ~> 4.0 |
| azuread | ~> 3.0 |
| random | >= 3.5.0 |
| time | >= 0.9.0 |

## Providers

| Name | Description |
|------|-------------|
| azurerm | Azure Resource Manager provider |
| azuread | Azure Active Directory provider |

## Inputs

### Authentication

| Name | Description | Type | Default |
|------|-------------|------|---------|
| authentication_method | Authentication method: "client_secret" or "federated_credential" | string | "client_secret" |
| cxm_aws_account_id | CXM's AWS Account ID (for federated auth) | string | null |
| cxm_aws_role_arn | CXM's AWS IAM Role ARN (for federated auth) | string | null |

### Feature Toggles

| Name | Description | Type | Default |
|------|-------------|------|---------|
| enable_asset_discovery | Enable Reader roles for asset discovery | bool | true |
| enable_billing_export_access | Enable access to Cost Management exports | bool | true |
| enable_activity_log_access | Enable access to Activity Logs | bool | true |
| enable_directory_reader | Enable Directory Reader role | bool | true |

### Scope Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| use_management_group | Grant access at Management Group level | bool | false |
| management_group_id | Management Group ID | string | "" |
| all_subscriptions | Grant access to all subscriptions | bool | false |
| subscription_ids | List of subscription IDs | list(string) | [] |
| subscription_exclusions | Subscriptions to exclude | list(string) | [] |

### Storage Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| billing_export_storage_account_name | Storage account for cost exports | string | "" |
| billing_export_storage_resource_group | Resource group for cost exports storage | string | "" |
| activity_log_storage_account_name | Storage account for activity logs | string | "" |
| activity_log_storage_resource_group | Resource group for activity logs storage | string | "" |

### Existing Resources

| Name | Description | Type | Default |
|------|-------------|------|---------|
| use_existing_ad_application | Use existing Azure AD Application | bool | false |
| existing_client_id | Existing Application Client ID | string | "" |
| existing_service_principal_id | Existing Service Principal ID | string | "" |
| existing_client_secret | Existing client secret | string | "" |

### Naming

| Name | Description | Type | Default |
|------|-------------|------|---------|
| prefix | Prefix for resource names | string | "cxm" |
| application_name | Azure AD Application name | string | "cxm-asset-crawler" |
| tags | Tags for created resources | map(string) | {} |

## Outputs

| Name | Description |
|------|-------------|
| cxm_onboarding_values | All values needed for CXM onboarding (sensitive) |
| tenant_id | Azure AD Tenant ID |
| client_id | Azure AD Application Client ID |
| service_principal_id | Service Principal Object ID |
| client_secret | Client secret (if using client_secret auth) |
| authentication_method | Configured authentication method |
| subscription_ids | List of enabled subscription IDs |
| features_enabled | Summary of enabled features |

## Permissions Granted

### Asset Discovery

- **Reader**: Read access to all Azure resources
- **Monitoring Reader**: Read access to monitoring data
- **Key Vault Reader**: Read access to Key Vault metadata (not secrets)

### Billing Export Access

Custom role with:
- Read storage account and containers
- Read blob data
- List storage keys
- Read Cost Management exports

### Activity Log Access

Custom role with:
- Read storage account and containers
- Read blob data
- List storage keys
- Read diagnostic settings

### Directory Reader (Optional)

- Read Users, Groups, and Service Principals from Microsoft Graph API

## Security Considerations

1. **Least Privilege**: The module grants read-only access. No write or delete permissions are granted.

2. **Data Plane Exclusion**: Access to actual data in services (e.g., database contents, storage blobs outside of export containers) is NOT granted.

3. **Federated Credentials**: For enhanced security, consider using federated credentials instead of client secrets.

## Troubleshooting

### "Insufficient privileges to complete the operation"

This error typically occurs when assigning the Directory Reader role. Ensure the user running Terraform has Azure AD administrative privileges, or set `enable_directory_reader = false`.

### "Storage account not found"

Ensure the storage account names and resource groups are correct and the Azure provider has access to them.

### "Management group not found"

Verify the management group ID is correct. Use `az account management-group list` to find the correct ID.

## License

Copyright (c) Cloud ex Machina. All rights reserved.
