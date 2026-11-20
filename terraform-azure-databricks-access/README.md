# CXM Databricks Access

Gives the CXM Service Principal read-only access to the Databricks system tables of one Azure Databricks workspace, and a dedicated SQL warehouse to query them. CXM uses this data for Databricks cost and usage analysis.

The module uses the existing CXM Service Principal. It does not create a new Azure identity.

## Prerequisites

- The workspace is attached to a Unity Catalog metastore.
- The identity that runs Terraform is a workspace admin.
- To enable the system schemas (`enable_system_schemas = true`), the identity is also a metastore admin.

## Usage

Call the module once per workspace, each with its own `databricks` provider.

```hcl
provider "databricks" {
  host = "https://adb-1234567890123456.7.azuredatabricks.net"
}

module "cxm_databricks_access" {
  source = "github.com/cxmlabs/terraform-azure-cxm-integration//terraform-azure-databricks-access"

  service_principal_application_id = "<client_id of the CXM integration>"
}
```

Provide the `workspace_url` and `sql_warehouse_id` outputs to CXM.

## Permissions Granted

| Object | Privilege |
|--------|-----------|
| Workspace | CXM Service Principal, with the Databricks SQL access entitlement |
| Catalog `system` | USE_CATALOG |
| Schemas `system.billing`, `system.compute`, `system.lakeflow`, `system.query`, `system.access` | USE_SCHEMA, SELECT |
| SQL warehouse `cxm` | CAN_USE |

The grants are additive (`databricks_grant`). The module does not change the grants of other principals.

The CXM SQL warehouse is small (2X-Small, one cluster, auto-stop after 10 minutes). Its cost stays separate from your other warehouses.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| service_principal_application_id | Application (Client) ID of the CXM Service Principal | string | required |
| service_principal_display_name | Display name in the workspace | string | "cxm-asset-crawler" |
| system_schemas | System schemas that CXM reads | list(string) | ["billing", "compute", "lakeflow", "query", "access"] |
| enable_system_schemas | Enable the system schemas (needs a metastore admin) | bool | false |
| warehouse_name | Name of the CXM SQL warehouse | string | "cxm" |
| warehouse_cluster_size | Cluster size of the CXM SQL warehouse | string | "2X-Small" |
| warehouse_auto_stop_mins | Idle minutes before the warehouse stops | number | 10 |
| warehouse_serverless | Use serverless compute for the warehouse | bool | true |

## Outputs

| Name | Description |
|------|-------------|
| workspace_url | URL of the Databricks workspace |
| sql_warehouse_id | ID of the CXM SQL warehouse |

## Manual Setup

Use these steps when you do not use Terraform.

1. In the workspace, open **Settings > Identity and access > Service principals**. Add the CXM Service Principal with its Application (Client) ID. Give it the **Databricks SQL access** entitlement.
2. As a metastore admin, enable the system schemas that are not enabled yet:

   ```bash
   databricks system-schemas enable <metastore-id> compute
   databricks system-schemas enable <metastore-id> lakeflow
   databricks system-schemas enable <metastore-id> query
   databricks system-schemas enable <metastore-id> access
   ```

3. In a SQL editor, run the grants. Replace `<application-id>` with the Application (Client) ID:

   ```sql
   GRANT USE CATALOG ON CATALOG system TO `<application-id>`;
   GRANT USE SCHEMA, SELECT ON SCHEMA system.billing TO `<application-id>`;
   GRANT USE SCHEMA, SELECT ON SCHEMA system.compute TO `<application-id>`;
   GRANT USE SCHEMA, SELECT ON SCHEMA system.lakeflow TO `<application-id>`;
   GRANT USE SCHEMA, SELECT ON SCHEMA system.query TO `<application-id>`;
   GRANT USE SCHEMA, SELECT ON SCHEMA system.access TO `<application-id>`;
   ```

4. Create a SQL warehouse named `cxm` (2X-Small, auto-stop 10 minutes). In its **Permissions**, give the CXM Service Principal **Can use**.
5. Provide the workspace URL and the warehouse ID to CXM.
