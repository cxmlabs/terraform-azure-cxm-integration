# Existing Resources Example

The common production case: the FOCUS Cost Management export and its storage
account already exist, and CXM is granted **read-only** access across a specific
list of subscriptions.

## What it does

- Creates the CXM App Registration / Service Principal (client-secret auth).
- Grants Reader, Monitoring Reader and Key Vault Reader on the listed subscriptions.
- Grants read-only access to the **existing** cost-export and activity-log storage
  accounts (nothing is created in them).
- Emits `cxm_onboarding_values` with the exact keys the CXM Azure datasource expects.

## Usage

```bash
terraform init
terraform plan
terraform apply

# Retrieve the onboarding values (paste straight into CXM):
terraform output -json cxm_onboarding_values
```

The output keys — `azure_tenant_id`, `azure_client_id`, `azure_client_secret`,
`azure_subscription_ids`, `azure_billing_export_storage_account`,
`azure_billing_export_resource_group`, `azure_focus_path` — match the datasource
inputs one-to-one.

## Finding `billing_export_focus_path`

The FOCUS export writes parquet under
`az://<container>/<root-folder>/<export-name>/**/*.parquet`. Read the container,
root folder and export name from **Cost Management > Exports** for your export, e.g.
`az://cost-exports/daily/cxm-daily-export-focus/**/*.parquet`.

Leave `billing_export_focus_path` empty only when you set
`billing_export_create_cost_exports = true` (then the module derives the path).
