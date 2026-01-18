# Infrastructure Documentation

This directory contains Azure infrastructure as code (IaC) using Bicep and Azure Verified Modules (AVM) for deploying a FastAPI Function App with managed identity authentication.

## Quick Start

Deploy the infrastructure using Azure Developer CLI (azd):

```bash
# Set your naming seed (generates all resource names)
azd env set AZD_NAME_SEED funcsj

# Authenticate to Azure
azd auth login

# Provision infrastructure and deploy code
azd up
```

## Directory Structure

```
infra/
├── main.bicep              # Main infrastructure template (subscription scope)
├── main.parameters.json    # Parameter mappings for azd
├── abbreviations.json      # Azure resource naming abbreviations
└── app/
    ├── api.bicep          # Function App configuration
    └── rbac.bicep         # Role-based access control assignments
```

## Resource Naming

All resource names are generated from a **single seed string** (`nameSeed` parameter) for consistency:

- **Seed**: Set via `AZD_NAME_SEED` environment variable or defaults to `environmentName`
- **Token**: Unique hash generated from `subscription().id`, seed, and location
- **Naming pattern**: `<abbreviation><normalized-seed>-<token>` or `<abbreviation><normalized-seed><short-token>`

### Examples

If `AZD_NAME_SEED=funcsj` and location is `swedencentral`:

| Resource Type | Abbreviation | Generated Name |
|---------------|--------------|----------------|
| Resource Group | `rg-` | `rg-funcsj` |
| Function App | `func-` | `func-funcsj-adx4gbhmgueca` |
| Storage Account | `st` | `stfuncsjadx4gb` (24 char limit) |
| App Insights | `appi-` | `appi-funcsj-adx4gbhmgueca` |
| Managed Identity | `id-` | `id-funcsj-adx4gbhmgueca` |
| App Service Plan | `plan-` | `plan-funcsj-adx4gbhmgueca` |
| Log Analytics | `log-` | `log-funcsj-adx4gbhmgueca` |

## Architecture

### Key Components

1. **Flex Consumption Function App (FC1)**
   - Serverless, pay-per-execution model
   - Python 3.13 runtime
   - Linux OS (required for Python)
   - Managed identity for all authentication

2. **User-Assigned Managed Identity**
   - No connection strings or secrets stored
   - Used by Function App for storage and App Insights access
   - Automatic credential rotation by Azure

3. **Storage Account**
   - SKU: Standard_LRS
   - Network ACLs: Allow Azure services bypass
   - Shared key access: Disabled (enforced by policy)
   - Managed identity authentication only

4. **Application Insights + Log Analytics**
   - Monitoring and telemetry
   - AAD authentication (no instrumentation keys)
   - 30-day data retention

5. **RBAC Role Assignments**
   - **Storage Blob Data Owner**: Managed identity → Storage (for Function operations)
   - **Monitoring Metrics Publisher**: Managed identity → App Insights (for telemetry)
   - **Storage Blob Data Owner**: Deploying user → Storage (for deployment package uploads)

### Security Features

- **No shared keys**: Storage uses managed identity exclusively
- **No connection strings**: All authentication via Azure AD
- **Network security**: Storage allows Azure services bypass for deployment
- **Least privilege**: Specific RBAC roles for each operation

## File Details

### main.bicep

**Scope**: `subscription` (deploys resource group and all resources)

**Key Parameters**:
- `environmentName` (required): azd environment name
- `nameSeed` (optional): Seed for resource naming, defaults to `environmentName`
- `location` (required): Azure region
- `principalId` (optional): User identity for deployment access, defaults to `deployer().objectId`
- `allowUserIdentityPrincipal` (default: `true`): Grant deployer storage access

**Overridable Resource Names**:
- `functionAppName`
- `userAssignedIdentityName`
- `applicationInsightsName`
- `appServicePlanName`
- `logAnalyticsName`
- `resourceGroupName`
- `storageAccountName`

**Key Outputs**:
- `AZURE_LOCATION`
- `AZURE_TENANT_ID`
- `RESOURCE_GROUP`
- `AZURE_FUNCTION_APP_NAME`
- `AZURE_STORAGE_ACCOUNT_NAME`
- `APPLICATIONINSIGHTS_CONNECTION_STRING`

### main.parameters.json

Maps azd environment variables to Bicep parameters:

```json
{
  "environmentName": "${AZURE_ENV_NAME}",        // azd environment name
  "location": "${AZURE_LOCATION}",              // Selected Azure region
  "principalId": "${AZURE_PRINCIPAL_ID}",       // Deploying user's principal ID
  "nameSeed": "${AZD_NAME_SEED}"                // Custom naming seed
}
```

### app/api.bicep

Configures the Azure Function App using AVM module `avm/res/web/site:0.15.1`.

**Key Features**:
- Flex Consumption plan (`functionAppConfig`)
- User-assigned managed identity
- Deployment storage with managed identity auth
- Application settings for storage and App Insights
- Scale settings (2048 MB, max 100 instances)

**App Settings**:
- `AzureWebJobsStorage__accountName`: Storage account name
- `AzureWebJobsStorage__credential`: `managedidentity`
- `AzureWebJobsStorage__clientId`: Managed identity client ID
- `AzureWebJobsStorage__blobServiceUri`: Blob endpoint (if blob enabled)
- `APPLICATIONINSIGHTS_AUTHENTICATION_STRING`: AAD auth for App Insights
- `APPLICATIONINSIGHTS_CONNECTION_STRING`: App Insights connection string

### app/rbac.bicep

Assigns RBAC roles for managed identity and optional user identity.

**Role Assignments**:

| Role | Assignee | Scope | Purpose |
|------|----------|-------|---------|
| Storage Blob Data Owner | Managed Identity | Storage Account | Function App operations |
| Storage Queue Data Contributor | Managed Identity | Storage Account | Queue triggers (if enabled) |
| Storage Table Data Contributor | Managed Identity | Storage Account | Table storage (if enabled) |
| Monitoring Metrics Publisher | Managed Identity | App Insights | Telemetry publishing |
| Storage Blob Data Owner | Deploying User | Storage Account | Deploy package uploads |
| Monitoring Metrics Publisher | Deploying User | App Insights | Testing access |

**Conditional Assignments**:
- Storage roles assigned only if feature enabled (`enableBlob`, `enableQueue`, `enableTable`)
- User identity roles assigned only if `allowUserIdentityPrincipal=true`

### abbreviations.json

Azure resource naming abbreviations based on [Microsoft Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations):

```json
{
  "resourcesResourceGroups": "rg-",
  "storageStorageAccounts": "st",
  "managedIdentityUserAssignedIdentities": "id-",
  "webServerFarms": "plan-",
  "webSitesFunctions": "func-",
  "operationalInsightsWorkspaces": "log-",
  "insightsComponents": "appi-"
}
```

## Azure Verified Modules (AVM)

This infrastructure uses the latest [Azure Verified Modules](https://aka.ms/avm) from the Bicep public registry:

| Module | Version | Purpose |
|--------|---------|---------|
| `avm/res/managed-identity/user-assigned-identity` | 0.4.1 | User-assigned managed identity |
| `avm/res/web/serverfarm` | 0.1.1 | App Service Plan (Flex Consumption) |
| `avm/res/storage/storage-account` | 0.8.3 | Storage account with containers |
| `avm/res/operational-insights/workspace` | 0.11.1 | Log Analytics workspace |
| `avm/res/insights/component` | 0.6.0 | Application Insights |
| `avm/res/web/site` | 0.15.1 | Function App configuration |

**Benefits**:
- Microsoft-verified best practices
- Consistent parameter interface
- Regular updates and security patches
- Built-in RBAC and networking support

## Deployment Process

### 1. Infrastructure Provisioning (`azd provision` or `azd up`)

**Steps**:
1. Create resource group
2. Deploy user-assigned managed identity
3. Deploy App Service Plan (Flex Consumption FC1)
4. Deploy storage account with blob container
5. Deploy Log Analytics workspace
6. Deploy Application Insights (linked to Log Analytics)
7. Deploy Function App with managed identity and deployment storage config
8. Assign RBAC roles (managed identity and user identity)

**Important**: RBAC role assignments can take 30-90 seconds to propagate globally.

### 2. Code Deployment (`azd deploy`)

**Steps**:
1. Package Function App code into zip
2. Authenticate to Azure using azd credentials
3. Upload zip to deployment storage container using user identity
4. Function App downloads and deploys code using managed identity
5. Azure Oryx builds dependencies (`remote-build: true`)

### 3. Cleanup (`azd down`)

Deletes the resource group and all contained resources.

## Configuration Options

### Enable Queue/Table Storage

Update `storageEndpointConfig` in `main.bicep`:

```bicep
var storageEndpointConfig = {
  enableBlob: true
  enableQueue: true   // Enable for queue triggers
  enableTable: true   // Enable for table storage
  enableFiles: false
  allowUserIdentityPrincipal: true
}
```

### Disable User Identity Access

Set parameter to prevent deploying user from accessing storage:

```bicep
param allowUserIdentityPrincipal bool = false
```

**Note**: Requires alternative deployment method (e.g., GitHub Actions with service principal).

### Custom Resource Names

Override any resource name in `main.bicep` parameters:

```bash
azd env set FUNCTION_APP_NAME my-custom-func-name
azd provision
```

Or set in `main.parameters.json`:

```json
{
  "functionAppName": {
    "value": "my-custom-func-name"
  }
}
```

### Scale Configuration

Modify in `app/api.bicep`:

```bicep
scaleAndConcurrency: {
  instanceMemoryMB: 4096        // 2048 or 4096 MB
  maximumInstanceCount: 200     // Max instances
}
```

## Troubleshooting

### Storage 403 Errors During Deployment

**Cause**: Network firewall or missing RBAC roles

**Solution**: 
1. Verify `networkAcls` allows Azure services:
   ```bicep
   networkAcls: {
     bypass: 'AzureServices'
     defaultAction: 'Allow'
   }
   ```
2. Wait 60-90 seconds after `azd provision` before `azd deploy`
3. Verify user identity has Storage Blob Data Owner role

### Application Insights Not Receiving Logs

**Cause**: Missing connection string in app settings

**Solution**: Verify `APPLICATIONINSIGHTS_CONNECTION_STRING` is set in Function App settings (fixed in `app/api.bicep`)

### Deployment Package Upload Fails

**Cause**: Storage firewall blocking deployment or missing user RBAC

**Solution**:
1. Ensure `allowUserIdentityPrincipal=true` in `main.bicep`
2. Verify storage network allows Azure services bypass
3. Run `azd provision` to apply RBAC changes

## Best Practices

1. **Always use `nameSeed`** for consistent resource naming across environments
2. **Wait for RBAC propagation** (30-90s) after infrastructure changes
3. **Use `azd up`** for combined provision + deploy workflow
4. **Enable `remoteBuild`** in `azure.yaml` for dependency compatibility
5. **Keep `allowUserIdentityPrincipal=true`** for azd deployment workflow
6. **Version AVM modules** for predictable deployments
7. **Use managed identity exclusively** - avoid connection strings

## References

- [Azure Verified Modules](https://aka.ms/avm)
- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Flex Consumption Plan for Azure Functions](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan)
- [Managed Identity Best Practices](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/managed-identity-best-practice-recommendations)
- [Azure Functions Python Developer Guide](https://learn.microsoft.com/azure/azure-functions/functions-reference-python)
