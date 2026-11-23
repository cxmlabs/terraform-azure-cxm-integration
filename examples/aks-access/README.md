# AKS Access Example

This example installs the CXM integration and gives its Service Principal read access to the Kubernetes API of the AKS clusters of the subscription, in one configuration.

## Prerequisites

1. Azure CLI installed and authenticated (`az login`)
2. Terraform >= 1.9.0 installed
3. Existing storage accounts for:
   - Cost Management exports
   - Activity logs
4. The identity that runs Terraform can create custom roles and role assignments on the subscription, for example as Owner or User Access Administrator
5. The AKS clusters use Entra ID and Azure RBAC. The [AKS Access module](../../terraform-azure-aks-access/) gives the limits.

## Usage

1. Update the storage account names and the resource groups in `main.tf`

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
   ```

## What Gets Created

- Azure AD Application (`cxm-asset-crawler`)
- Service Principal with client secret
- Reader role assignments on the current subscription
- Custom roles for storage access
- The custom role `CXM AKS Reader`, and its assignment to the CXM Service Principal on the current subscription
