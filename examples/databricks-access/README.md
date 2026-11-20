# Databricks Access Example

This example installs the CXM integration and gives its Service Principal read-only access to the Databricks system tables of one Unity Catalog metastore, in one configuration.

## Prerequisites

1. Azure CLI installed and authenticated (`az login`)
2. Terraform >= 1.9.0 installed
3. Existing storage accounts for:
   - Cost Management exports
   - Activity logs
4. An Azure Databricks workspace attached to a Unity Catalog metastore. You are a workspace admin of the workspace, and both a metastore admin of its metastore and an account admin.
5. The system schemas are enabled, as the [Azure Databricks Access guide](https://docs.cloudexmachina.io/setup/csp-configuration/azure-setup/databricks) says

## Usage

1. Update the storage account names, the resource groups and the Databricks workspace URL in `main.tf`

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review the plan:
   ```bash
   terraform plan
   ```

4. Apply the configuration:
   ```bash
   terraform apply
   ```

5. Get the onboarding values:
   ```bash
   terraform output -json cxm_onboarding_values
   terraform output -json cxm_databricks_values
   ```

## What Gets Created

- Azure AD Application (`cxm-asset-crawler`)
- Service Principal with client secret
- Reader role assignments on the current subscription
- Custom roles for storage access
- The CXM Service Principal in the Databricks workspace, with the Databricks SQL access entitlement
- `USE_CATALOG` on the `system` catalog, and `USE_SCHEMA` and `SELECT` on its schemas `billing`, `compute`, `lakeflow`, `query` and `access`
- A SQL warehouse named `cxm` (2X-Small, auto-stop 10 minutes), with `CAN_USE` for the CXM Service Principal
