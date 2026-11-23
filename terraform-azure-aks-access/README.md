# CXM AKS Access

Gives the CXM Service Principal read access to the Kubernetes API of the AKS clusters of the integration. The module creates the custom role `CXM AKS Reader` and assigns it to the existing CXM Service Principal on each subscription. It does not create a new Azure identity, and it makes no change in the clusters.

## What the role reads

The role reads all Kubernetes objects except Secrets:

| Permission | Value |
|------------|-------|
| actions | none |
| dataActions | `Microsoft.ContainerService/managedClusters/*/read` |
| notDataActions | `Microsoft.ContainerService/managedClusters/secrets/read` |

ConfigMaps and pod specs can hold plain-text values, and the role reads them. The role also reads pod logs, which can hold plain-text values too. The role reads nodes. On AKS, this also allows `get` on `nodes/proxy`, which can run commands in pods through the kubelet. AKS has no separate data action to deny it.

The role holds no ARM action. The Reader role of the integration gives CXM the API server address of each cluster, and Entra ID gives CXM its token.

## Supported clusters

The role is safe only on clusters with Entra ID and Azure RBAC. On these clusters, each Kubernetes request is authorized by the Azure role, so no change in the cluster is necessary.

## Limits

- A cluster without Entra ID and Azure RBAC gives CXM no access: the role holds no action that gets a cluster credential.
- A cluster with Entra ID and Kubernetes RBAC only authorizes each request with Kubernetes RBAC, not with the Azure role. It needs an in-cluster ClusterRoleBinding, which this module does not create.
- A private cluster, or a cluster with authorized IP ranges, must let the CXM egress reach its API server.
- Azure cannot assign a custom role with data actions at a management-group scope ([custom role limits](https://learn.microsoft.com/azure/role-based-access-control/custom-roles#custom-role-limits)). In management-group mode, the role is assignable at the management group, and each subscription of the management group in the state `Enabled` gets an assignment. A subscription that joins the management group later gets its assignment at the next apply.
- In subscription mode, the role is assignable on each subscription of `subscription_ids` and on the subscription of the provider. The role is defined on the subscription of the provider, so a change of `subscription_ids` does not replace it. `subscription_ids` must hold at least one subscription. A new subscription needs a new apply.

## Usage

Set `enable_aks_access = true` on the root module. The root module passes its subscriptions or its management group to this module:

```hcl
module "cxm_integration" {
  source = "github.com/cxmlabs/terraform-azure-cxm-integration"

  # ... other configuration ...

  enable_aks_access = true
}
```

The [aks-access example](../examples/aks-access/) installs the CXM integration and this module in one configuration.

## Import a role created by hand

If you already created a `CXM AKS Reader` role and its assignments by hand, import them before you apply. Otherwise Azure refuses the second role with the same name. Replace `cxm_integration` with the name of your module call.

Get the role ID and the assignment IDs:

```bash
az role definition list --name "CXM AKS Reader" --query "[].id" -o tsv
az role assignment list --assignee <client-id> --role "CXM AKS Reader" --all --query "[].id" -o tsv
```

Then add `import` blocks next to the module call. The role ID is the printed role ID, a `|`, and the scope of the role: `/subscriptions/<id>` of the subscription of the provider, or the management group ID in management-group mode. Add one assignment block for each subscription:

```hcl
import {
  to = module.cxm_integration.module.aks_access[0].azurerm_role_definition.aks_reader
  id = "<role-id>|<role-scope>"
}

import {
  to = module.cxm_integration.module.aks_access[0].azurerm_role_assignment.aks_reader["/subscriptions/<subscription-id>"]
  id = "<assignment-id>"
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| service_principal_id | Object ID of the CXM Service Principal | string | - |
| subscription_ids | Subscriptions that get the role (subscription mode) | list(string) | [] |
| use_management_group | Make the role assignable at the management group, and assign it on each of its subscriptions | bool | false |
| management_group_id | ID of the management group (management-group mode) | string | "" |
| subscription_exclusions | Subscriptions that get no assignment in management-group mode | list(string) | [] |

## Outputs

| Name | Description |
|------|-------------|
| role_definition_id | GUID of the CXM AKS Reader role, the same in each assignable scope |
| role_name | Name of the custom role |
