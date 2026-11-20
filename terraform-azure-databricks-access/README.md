# CXM Databricks Access

Gives the CXM Service Principal read-only access to the Databricks system tables of one Unity Catalog metastore, and a dedicated SQL warehouse to query them. CXM uses this data for Databricks cost and usage analysis.

The module uses the existing CXM Service Principal. It does not create a new Azure identity.

## Prerequisites

- The workspace is attached to a Unity Catalog metastore.
- The identity that runs Terraform is a workspace admin of the workspace. It is also both a metastore admin of its metastore and an account admin, because a workspace admin cannot grant on the `system` catalog ([Grant access to system tables](https://learn.microsoft.com/azure/databricks/admin/system-tables/#grant-access-to-system-tables)).
- The system schemas are enabled. The module does not enable them. As a metastore admin, enable them first, as the [Azure Databricks Access guide](https://docs.cloudexmachina.io/setup/csp-configuration/azure-setup/databricks) says.

## Usage

The system tables of a metastore cover all its workspaces. Call the module once per metastore, in one workspace of that metastore, each with its own `databricks` provider.

```hcl
provider "databricks" {
  host = "https://adb-1234567890123456.7.azuredatabricks.net"
}

module "cxm_databricks_access" {
  source = "github.com/cxmlabs/terraform-azure-cxm-integration//terraform-azure-databricks-access"

  service_principal_application_id = "<client_id of the CXM integration>"
}
```

For a second metastore, add an aliased `databricks` provider for one workspace of that metastore, and pass it to a second module call:

```hcl
provider "databricks" {
  alias = "second_metastore"
  host  = "https://adb-6543210987654321.1.azuredatabricks.net"
}

module "cxm_databricks_access_second_metastore" {
  source = "github.com/cxmlabs/terraform-azure-cxm-integration//terraform-azure-databricks-access"

  providers = {
    databricks = databricks.second_metastore
  }

  service_principal_application_id = "<client_id of the CXM integration>"
}
```

Provide the `workspace_url` and `sql_warehouse_id` outputs of each module call to CXM. The [databricks-access example](../examples/databricks-access/) installs the CXM integration and this module in one configuration.

## Permissions Granted

| Object | Privilege |
|--------|-----------|
| Workspace | CXM Service Principal, with the Databricks SQL access entitlement |
| Catalog `system` | USE_CATALOG |
| Schemas `system.billing`, `system.compute`, `system.lakeflow`, `system.query`, `system.access` | USE_SCHEMA, SELECT |
| SQL warehouse `cxm` | CAN_USE |

The grants on the `system` catalog and its schemas are additive (`databricks_grant`). The module does not change the grants of other principals.

The CXM service principal joins the workspace `users` group, as each workspace user does. On a workspace with a workspace catalog, workspace users get `USE CATALOG` on that catalog, and `USE SCHEMA`, `CREATE TABLE`, `CREATE VOLUME`, `CREATE MODEL`, `CREATE FUNCTION` and `CREATE MATERIALIZED VIEW` on its `default` schema ([Admin privileges in Unity Catalog](https://learn.microsoft.com/azure/databricks/data-governance/unity-catalog/manage-privileges/admin-privileges)). The module adds no revoke. To see these grants, run `SHOW GRANTS ON CATALOG <workspace-catalog>;` and `SHOW GRANTS ON SCHEMA <workspace-catalog>.default;`.

The module owns the `cxm` SQL warehouse. Its permissions (`databricks_permissions`) are authoritative: Terraform controls the full permission list of this warehouse. It removes a permission that you add outside Terraform.

The `cxm` SQL warehouse is small (2X-Small, one cluster, auto-stop after 10 minutes). Its cost stays separate from your other warehouses.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| service_principal_application_id | Application (Client) ID of the CXM Service Principal | string | required |
| system_schemas | System schemas that CXM reads. Remove `query` and `access` to exclude query history and audit events | list(string) | ["billing", "compute", "lakeflow", "query", "access"] |
| warehouse_serverless | Use serverless compute for the warehouse. Set false where serverless SQL is not available | bool | true |

## Outputs

| Name | Description |
|------|-------------|
| workspace_url | URL of the Databricks workspace |
| sql_warehouse_id | ID of the CXM SQL warehouse |

## Manual Setup

To give the same access without Terraform, follow the [Azure Databricks Access guide](https://docs.cloudexmachina.io/setup/csp-configuration/azure-setup/databricks).
