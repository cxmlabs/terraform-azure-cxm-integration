# All Subscriptions Example

This example deploys the CXM integration to all subscriptions visible to the current user, with optional exclusions.

## When to Use

- Medium-sized organizations that want comprehensive coverage
- When you don't have a management group hierarchy set up
- When you want explicit control over which subscriptions are included/excluded

## Prerequisites

1. Azure CLI installed and authenticated
2. Terraform >= 1.9.0 installed
3. User must have access to list all subscriptions in the tenant
4. Existing storage accounts for cost exports and activity logs

## Usage

1. Update `main.tf`:
   - Update storage account names and resource groups
   - Optionally add subscription IDs to `subscription_exclusions`

2. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## How It Works

The module:
1. Lists all enabled subscriptions visible to the current user
2. Filters out any subscriptions in `subscription_exclusions`
3. Creates Reader role assignments on each remaining subscription
4. Outputs the list of enabled subscription IDs

## Notes

- New subscriptions added after deployment will NOT automatically get access
- Run `terraform apply` again to include new subscriptions
- For automatic inclusion of new subscriptions, use the Management Group example instead
