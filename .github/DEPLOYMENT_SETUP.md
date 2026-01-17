# GitHub Actions Deployment Setup Guide

This guide will help you configure GitHub Actions to automatically deploy your FastAPI Azure Function on every push to the `main` branch.

## 🔐 Setup Azure OIDC Authentication (One-Time Setup)

### Prerequisites
- Azure subscription
- Azure Function App already created (use `scripts/deploy-azure.sh`)
- GitHub repository with admin access

### Step 1: Create Azure AD App Registration

```bash
# Login to Azure
az login

# Create app registration
APP_NAME="github-actions-oidc"
APP_ID=$(az ad app create --display-name $APP_NAME --query appId -o tsv)
echo "Application (Client) ID: $APP_ID"

# Create service principal
az ad sp create --id $APP_ID

# Get service principal object ID
SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query id -o tsv)
```

### Step 2: Assign Contributor Role to Function App

```bash
# Set your variables
SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP="azure-function-rg-sj"
FUNCTION_APP_NAME="my-fastapi-func-sj"

# Get Function App resource ID
FUNCTION_APP_ID=$(az functionapp show \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query id -o tsv)

# Assign Contributor role
az role assignment create \
  --role Contributor \
  --assignee $APP_ID \
  --scope $FUNCTION_APP_ID
```

### Step 3: Configure Federated Credentials for GitHub

```bash
# Get your GitHub repository info
GITHUB_ORG="your-github-username-or-org"
GITHUB_REPO="fastapi-azure-functions"

# Create federated credential for main branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_ORG'/'$GITHUB_REPO':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### Step 4: Get Required IDs

```bash
# Get Tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

# Get Subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Display all required values
echo ""
echo "======================================"
echo "GitHub Secrets Configuration Values:"
echo "======================================"
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_TENANT_ID: $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo "AZURE_FUNCTIONAPP_NAME: $FUNCTION_APP_NAME"
echo "======================================"
```

## 🔑 Configure GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add each of the following:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AZUREAPPSERVICE_CLIENTID_*` | From Step 4 above | Application (Client) ID (auto-generated name) |
| `AZUREAPPSERVICE_TENANTID_*` | From Step 4 above | Azure AD Tenant ID (auto-generated name) |
| `AZUREAPPSERVICE_SUBSCRIPTIONID_*` | From Step 4 above | Azure Subscription ID (auto-generated name) |

> **Note**: The secret names may have auto-generated suffixes when created via Azure portal deployment center. Use the exact names from your workflow file.

## 📝 Understanding the GitHub Actions Workflow

### Workflow File Structure

The workflow (`.github/workflows/main_my-fastapi-func-sj.yml`) consists of two jobs:

#### Job 1: Build
```yaml
build:
  runs-on: ubuntu-latest
  steps:
    - Checkout repository
    - Setup Python 3.13
    - Zip source code only (no dependencies installed)
    - Upload artifact
```

**Key Points:**
- ✅ **No venv creation** - Dependencies are NOT installed locally
- ✅ **Source code only** - Zips raw source files and `requirements.txt`
- ✅ **Fast build** - No time wasted on dependency installation

#### Job 2: Deploy
```yaml
deploy:
  runs-on: ubuntu-latest
  needs: build
  steps:
    - Download build artifact
    - Login to Azure via OIDC
    - Deploy to Azure Functions with remote-build: true
```

**Key Points:**
- ✅ **OIDC Authentication** - Keyless, secure login using federated credentials
- ✅ **Remote Build** - Dependencies built on Azure (not GitHub runner)
- ✅ **Flex Consumption** - Optimized for Azure Functions Flex Consumption plan

### Critical Parameter: `remote-build: true`

```yaml
- name: 'Deploy to Azure Functions'
  uses: Azure/functions-action@v1
  with:
    app-name: 'my-fastapi-func-sj'
    slot-name: 'Production'
    package: ${{ env.AZURE_FUNCTIONAPP_PACKAGE_PATH }}
    remote-build: true  # ⚠️ CRITICAL for Flex Consumption
```

#### Why `remote-build: true` is Essential:

1. **Flex Consumption Plan Requirement**
   - Flex Consumption plans default to `remote-build: false` in GitHub Actions
   - Without `remote-build: true`, dependencies aren't installed on Azure
   - Results in "BadGateway" errors when the function tries to load missing packages

2. **Platform Compatibility**
   - Python packages with C extensions (e.g., numpy, pandas) need Linux builds
   - Building on GitHub's Ubuntu runner may create incompatible binaries
   - Azure's Oryx build system ensures compatibility with Azure Functions runtime

3. **Matches CLI Behavior**
   - `func azure functionapp publish` uses remote build by default
   - `remote-build: true` replicates this behavior in CI/CD

4. **Build Process with Remote Build:**
   ```
   GitHub Actions → Upload source.zip → Azure Kudu Service → 
   Oryx Build Engine → Install dependencies in Linux → 
   Create deployment package → Deploy to Function App ✅
   ```

5. **Build Process WITHOUT Remote Build (❌ Causes Errors):**
   ```
   GitHub Actions → Upload source.zip → Azure Kudu Service → 
   Deploy as-is (no dependency installation) → 
   Function fails: "BadGateway" ❌
   ```

### Environment Variables

```yaml
env:
  AZURE_FUNCTIONAPP_PACKAGE_PATH: '.'  # Deploy from repository root
  PYTHON_VERSION: '3.13'                # Must match Azure runtime
```

### Deployment Logs

During deployment, you'll see these Kudu pipeline steps:
```
[Kudu-ValidationStep] starting/completed
[Kudu-ExtractZipStep] starting/completed
[Kudu-OryxBuildStep] starting/completed  # ← Remote build happens here
[Kudu-PackageZipStep] starting/completed
[Kudu-UploadPackageStep] starting/completed
```

The `[Kudu-OryxBuildStep]` indicates Azure is building your dependencies remotely.

## ✅ Verify Setup

### Test the Workflow

1. Make a small change to your code
2. Commit and push to the `main` branch:
   ```bash
   git add .
   git commit -m "Test CI/CD deployment"
   git push origin main
   ```

3. Go to **Actions** tab in your GitHub repository
4. Watch the workflow run:
   - ✓ Build and test job should pass
   - ✓ Deploy job should authenticate via OIDC
   - ✓ Function should deploy successfully

### Manual Trigger

You can also manually trigger the workflow:
1. Go to **Actions** tab
2. Select **Deploy to Azure Functions** workflow
3. Click **Run workflow** → **Run workflow**

## 🎯 Workflow Status Badge

Add this badge to your README.md to show deployment status:

```markdown
[![Deploy to Azure Functions](https://github.com/YOUR_USERNAME/fastapi-azure-functions/actions/workflows/azure-functions-deploy.yml/badge.svg)](https://github.com/YOUR_USERNAME/fastapi-azure-functions/actions/workflows/azure-functions-deploy.yml)
```

Replace `YOUR_USERNAME` with your GitHub username or organization name.

## 🔧 Troubleshooting

### "BadGateway" Error After Successful Deployment

**Symptoms**: GitHub Actions shows "Successfully deployed" but function returns BadGateway error in Azure portal

**Cause**: Dependencies not installed on Azure (remote build disabled)

**Solution**: Verify `remote-build: true` in workflow file:
```yaml
- name: 'Deploy to Azure Functions'
  uses: Azure/functions-action@v1
  with:
    remote-build: true  # ← Must be present for Flex Consumption
```

**Check deployment logs** for:
```
✅ CORRECT: "Will use parameter remote-build: true"
❌ WRONG:   "Will use parameter remote-build: false"
```

### "Failed to login to Azure" Error
- Verify federated credential subject matches exactly: `repo:ORG/REPO:ref:refs/heads/main`
- Ensure role assignment propagated (wait 2-3 minutes after creation)
- Check all secrets are correctly set in GitHub

### "Permission denied" Error
- Verify the service principal has Contributor role on the Function App
- Check subscription ID is correct

### "Function app not found" Error
- Verify function app name in workflow matches actual Azure resource
- Ensure function app exists in Azure

### "Oryx Build Failed" Error
- Check `requirements.txt` has valid package names and versions
- Verify Python version in workflow (`3.13`) matches Azure runtime
- Review Kudu logs: `https://<app-name>.scm.azurewebsites.net/api/deployments`

### Deployment Succeeds Locally but Fails in GitHub Actions
- **Cause**: Local deployment (`func azure functionapp publish`) uses remote build by default
- **Solution**: Ensure `remote-build: true` in GitHub Actions workflow
- Compare deployment outputs - both should show `[Kudu-OryxBuildStep]` step

## 📚 Additional Resources

- [Azure OIDC Documentation](https://learn.microsoft.com/azure/developer/github/connect-from-azure)
- [GitHub Actions for Azure](https://github.com/Azure/actions)
- [Azure Functions Action](https://github.com/Azure/functions-action)

## 🔄 Deployment Flow

```
Push to main → Checkout Code → Setup Python → Install Dependencies 
→ Run Unit Tests → Run Integration Tests → Azure OIDC Login 
→ Deploy to Azure Functions → Verify Deployment ✅
```

---

**Need help?** Check the [GitHub Actions logs](../../actions) for detailed error messages.
