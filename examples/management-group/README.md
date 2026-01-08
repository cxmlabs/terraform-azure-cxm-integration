# Management Group Example

This example deploys the CXM integration at the Management Group level, granting access to all subscriptions under the management group.

## When to Use

- Large organizations with many subscriptions
- When you want automatic access to new subscriptions added under the management group
- When you have a well-organized management group hierarchy

## Prerequisites

1. Azure CLI installed and authenticated with appropriate permissions
2. Terraform >= 1.9.0 installed
3. Management Group ID (find via `az account management-group list`)
4. Existing storage accounts for cost exports and activity logs

## Usage

1. Update `main.tf`:
   - Set `management_group_id` to your management group ID
   - Update storage account names and resource groups

2. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Permissions Required

The user running Terraform needs:
- `Microsoft.Management/managementGroups/read` on the management group
- `Microsoft.Authorization/roleAssignments/write` on the management group
- Azure AD privileges to create applications and service principals
