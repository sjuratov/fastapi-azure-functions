# FastAPI on Azure Functions

[![Deploy to Azure Functions](https://github.com/YOUR_USERNAME/fastapi-azure-functions/actions/workflows/azure-functions-deploy.yml/badge.svg)](https://github.com/YOUR_USERNAME/fastapi-azure-functions/actions/workflows/azure-functions-deploy.yml)

This project demonstrates how to run a FastAPI application on Azure Functions
with secure, keyless authentication using managed identities.

Based on:
[Building your first serverless HTTP API on Azure with Azure Functions +
FastAPI](<https://devblogs.microsoft.com/cosmosdb/building-your-first-serverless-http-api-on-azure-with-azure-functions-fastapi/>)

## Prerequisites

- Python 3.13
- [uv](https://docs.astral.sh/uv/) package manager
- Azure Functions Core Tools
- Azure CLI

## Project Structure

```text
fastapi-azure-functions/
├── app/                     # Main application package
│   ├── main.py             # FastAPI app initialization
│   ├── config.py           # Configuration settings
│   ├── api/                # API routes
│   │   └── routes.py
│   ├── models/             # Pydantic models
│   │   └── requests.py
│   ├── services/           # Business logic
│   └── utils/              # Utility functions
├── scripts/                # Deployment scripts
│   ├── deploy-azure.ps1
│   └── deploy-azure.sh
├── tests/                  # Test suite
│   ├── conftest.py
│   └── test_api.py
├── function_app.py         # Azure Functions entry point
├── host.json               # Azure Functions host config
├── requirements.txt        # Python dependencies
├── pyproject.toml          # Project metadata
├── .funcignore             # Files excluded from deployment
└── test.http               # HTTP request samples
```

The `.funcignore` file ensures that only runtime code is deployed to Azure
(excludes tests, scripts, and documentation).

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
   - API: <http://localhost:7071/api/omy>
   - Swagger UI: <http://localhost:7071/api/docs>

4. Run tests:

   ```bash
   pytest
   ```

## Deploy to Azure

### GitHub Actions CI/CD (Recommended)

Automatically deploy to Azure Functions on every push to `main` branch:

1. **Setup OIDC Authentication**: Follow the comprehensive guide in [`.github/DEPLOYMENT_SETUP.md`](.github/DEPLOYMENT_SETUP.md)
2. **Configure GitHub Secrets**: Add Azure credentials to your repository
3. **Push to main**: Workflow automatically runs tests and deploys

**Setup Time**: ~5 minutes | **Zero stored credentials** ✅

#### How It Works

The GitHub Actions workflow (`.github/workflows/main_my-fastapi-func-sj.yml`):

1. **Build Job**:
   - Checks out code
   - Sets up Python 3.13
   - Zips source code (no dependencies installed)
   - Uploads artifact

2. **Deploy Job**:
   - Downloads artifact
   - Authenticates to Azure via OIDC (keyless)
   - Deploys with `remote-build: true` parameter
   - Azure builds dependencies using Oryx

**Key Feature**: `remote-build: true` ensures dependencies are built in Azure's Linux environment, preventing platform compatibility issues and "BadGateway" errors.

See [GitHub Actions Setup Guide](.github/DEPLOYMENT_SETUP.md) for detailed instructions and troubleshooting.

### Automated Deployment (Recommended)

Use the provided deployment scripts to provision all Azure resources with managed identity.

**Before running the scripts**, update the configuration variables at the top of the script:

- `ResourceGroup` / `RESOURCE_GROUP` - Your Azure resource group name
- `Location` / `LOCATION` - Azure region (swedencentral, eastus, westeurope)
- `StorageAccountName` / `STORAGE_ACCOUNT_NAME` - Storage account name
  (3-24 chars, lowercase/numbers only, globally unique)
- `IdentityName` / `IDENTITY_NAME` - Managed identity name
- `FunctionAppName` / `FUNCTION_APP_NAME` - Function app name (globally unique)

**PowerShell:**

```powershell
.\scripts\deploy-azure.ps1
```

**Bash/Linux/macOS:**

```bash
chmod +x scripts/deploy-azure.sh
./scripts/deploy-azure.sh
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

- Supports managed identity authentication during creation via
  `--deployment-storage-auth-type UserAssignedIdentity`
- Works with storage accounts that have shared key access disabled
- Regular consumption plan requires shared keys during creation,
  then conversion to managed identity

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

## Development

### Adding New Endpoints

1. Add route handlers in `app/api/routes.py` or create new router files
2. Define request/response models in `app/models/`
3. Add business logic in `app/services/`
4. Update tests in `tests/test_api.py`

### Project Benefits

- **Modular structure**: Easy to navigate and extend
- **Separation of concerns**: Routes, models, and logic are separate
- **Testability**: Full test suite with pytest
- **Clean deployments**: Only runtime code deployed via `.funcignore`
- **Scalability**: Ready for multiple functions and complex logic

## Testing

### Automated Testing

The project includes two types of automated tests:

#### Unit Tests (`tests/test_api.py`)

**Fast, isolated tests of FastAPI application logic.**

- Tests FastAPI routes directly using `TestClient`
- No Azure Functions runtime required
- Runs in-memory without HTTP server
- Ideal for testing business logic and API contracts
- **Run with:** `pytest tests/test_api.py` or
  `pytest -k "not integration"`

```bash
pytest tests/test_api.py
# ✓ 5 tests in ~0.02s
```

#### Integration Tests (`tests/test_integration.py`)

**Full end-to-end tests through Azure Functions runtime.**

- Makes real HTTP requests to `http://localhost:7071`
- Tests complete Azure Functions → ASGI → FastAPI integration
- Requires Functions host running (`func start`)
- Shows requests in Function logs
- **Run with:** `pytest tests/test_integration.py` or
  `pytest -m integration`

**Test against local Azure Functions:**

```bash
# Terminal 1: Start Azure Functions
func start

# Terminal 2: Run integration tests
pytest -m integration
# ✓ 6 tests through live Azure Functions runtime
```

**Test against deployed Azure Function:**

```bash
# Set the Azure Function URL via environment variable
FUNCTION_URL=https://your-app.azurewebsites.net pytest -m integration

# Or export it for multiple test runs
export FUNCTION_URL=https://your-app.azurewebsites.net
pytest -m integration
```

**Run all tests:**

```bash
pytest  # Runs both unit and integration tests
```

### Manual Testing

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

**Cause**: Managed identity doesn't have required permissions on
storage account

**Solution**: Ensure Storage Blob Data Owner role is assigned before creating
the Function App and wait 30 seconds for role propagation

### Application Insights not showing logs

**Cause**: Managed identity missing Monitoring Metrics Publisher role

**Solution**: Assign the role:

```bash
az role assignment create \
  --role "Monitoring Metrics Publisher" \
  --assignee <managed-identity-principal-id> \
  --scope <app-insights-resource-id>
```

### GitHub Actions deployment succeeds but function returns BadGateway

**Cause**: Dependencies not installed on Azure (missing `remote-build: true`)

**Solution**: Verify workflow file has:
```yaml
- name: 'Deploy to Azure Functions'
  uses: Azure/functions-action@v1
  with:
    remote-build: true  # Required for Flex Consumption plan
```

**Verify in deployment logs**:
- ✅ Should see: `Will use parameter remote-build: true`
- ✅ Should see: `[Kudu-OryxBuildStep] starting/completed`
- ❌ If missing, dependencies won't be installed

**Why this matters**: 
- Local deployment (`func azure functionapp publish`) uses remote build by default
- GitHub Actions defaults to `remote-build: false` for Flex Consumption
- Without remote build, Python packages aren't installed on Azure

See [Deployment Setup Guide](.github/DEPLOYMENT_SETUP.md#critical-parameter-remote-build-true) for details.

### Local Python version mismatch

**Cause**: Local Python version differs from Azure runtime (3.13)

**Solution**: Create a virtual environment with Python 3.13 or update the
runtime version in Azure to match your local version
