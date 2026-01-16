# FastAPI on Azure Functions

This project demonstrates how to run a FastAPI application on Azure Functions with secure, keyless authentication using managed identities.

Based on: [Building your first serverless HTTP API on Azure with Azure Functions + FastAPI](https://devblogs.microsoft.com/cosmosdb/building-your-first-serverless-http-api-on-azure-with-azure-functions-fastapi/)

## Prerequisites

- Python 3.13
- [uv](https://docs.astral.sh/uv/) package manager
- Azure Functions Core Tools
- Azure CLI

## Local Development

1. Install dependencies:
   ```bash
   uv sync
   ```

2. Run locally:
   ```bash
   func start
   ```

3. Test endpoints using `test.http` or visit:
   - API: http://localhost:7071/api/omy
   - Swagger UI: http://localhost:7071/api/docs

## Deploy to Azure

### Automated Deployment (Recommended)

Use the provided deployment scripts to provision all Azure resources with managed identity.

**Before running the scripts**, update the configuration variables at the top of the script:
- `ResourceGroup` / `RESOURCE_GROUP` - Your Azure resource group name
- `Location` / `LOCATION` - Azure region (e.g., swedencentral, eastus, westeurope)
- `StorageAccountName` / `STORAGE_ACCOUNT_NAME` - Storage account name (3-24 chars, lowercase/numbers only, globally unique)
- `IdentityName` / `IDENTITY_NAME` - Managed identity name
- `FunctionAppName` / `FUNCTION_APP_NAME` - Function app name (globally unique)

**PowerShell:**
```powershell
.\deploy-azure.ps1
```

**Bash/Linux/macOS:**
```bash
chmod +x deploy-azure.sh
./deploy-azure.sh
```

After the infrastructure is deployed, deploy your code:
```bash
func azure functionapp publish <FUNCTION_APP_NAME>
```

### What Gets Deployed

The deployment scripts create:
- **Azure Function App** (Flex Consumption Plan)
- **User-Assigned Managed Identity** (for keyless authentication)
- **Storage Account** (for Function App state)
- **Application Insights** (for monitoring and telemetry)
- **Role Assignments** (proper permissions for managed identity)

### Key Architecture Decisions

#### 1. Flex Consumption Plan vs Regular Consumption Plan

We use the **Flex Consumption plan** because:
- Supports managed identity authentication during creation via `--deployment-storage-auth-type UserAssignedIdentity`
- Works with storage accounts that have shared key access disabled
- Regular consumption plan requires shared keys during creation, then conversion to managed identity

#### 2. User-Assigned Managed Identity

Benefits:
- No connection strings or secrets stored in configuration
- Automatic credential rotation by Azure
- Complies with security policies that disable shared key access
- Single identity can be assigned to multiple resources

Required role assignments:
- **Storage Blob Data Owner** on the storage account (for Function App operations)
- **Monitoring Metrics Publisher** on Application Insights (for telemetry)

#### 3. Storage Account Configuration

- **Shared key access**: May be disabled by Azure Policy (security best practice)
- **Public blob access**: Disabled for security
- **Authentication**: Uses managed identity with proper RBAC roles

## Testing

Update the `@baseUrl` variable in `test.http` to switch between local and Azure environments:

```http
# Local Development
@baseUrl = http://localhost:7071

# Azure Function App
# @baseUrl = https://fastapi-function-demo-sj.azurewebsites.net
```

## Cleanup

To delete all Azure resources:

```bash
az group delete --name agent-toolkit-citadel-spoke --yes --no-wait
```

## Troubleshooting

### "403 Forbidden" during Function App creation

**Cause**: Managed identity doesn't have required permissions on storage account

**Solution**: Ensure Storage Blob Data Owner role is assigned before creating the Function App and wait 30 seconds for role propagation

### Application Insights not showing logs

**Cause**: Managed identity missing Monitoring Metrics Publisher role

**Solution**: Assign the role:
```bash
az role assignment create \
  --role "Monitoring Metrics Publisher" \
  --assignee <managed-identity-principal-id> \
  --scope <app-insights-resource-id>
```

### Local Python version mismatch

**Cause**: Local Python version differs from Azure runtime (3.13)

**Solution**: Create a virtual environment with Python 3.13 or update the runtime version in Azure to match your local version
