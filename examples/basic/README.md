# Basic Example - Single Subscription

This example deploys the CXM integration to a single subscription using client secret authentication.

## Prerequisites

1. Azure CLI installed and authenticated (`az login`)
2. Terraform >= 1.9.0 installed
3. Existing storage accounts for:
   - Cost Management exports
   - Activity logs

## Usage

1. Update the storage account names and resource groups in `main.tf`

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
