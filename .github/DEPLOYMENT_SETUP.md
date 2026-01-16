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
| `AZURE_CLIENT_ID` | From Step 4 above | Application (Client) ID |
| `AZURE_TENANT_ID` | From Step 4 above | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | From Step 4 above | Azure Subscription ID |
| `AZURE_FUNCTIONAPP_NAME` | Your function app name | e.g., `my-fastapi-func-sj` |

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

### "Failed to login to Azure" Error
- Verify federated credential subject matches exactly: `repo:ORG/REPO:ref:refs/heads/main`
- Ensure role assignment propagated (wait 2-3 minutes after creation)
- Check all secrets are correctly set in GitHub

### "Permission denied" Error
- Verify the service principal has Contributor role on the Function App
- Check subscription ID is correct

### "Function app not found" Error
- Verify `AZURE_FUNCTIONAPP_NAME` secret matches your actual function app name
- Ensure function app exists in Azure

### Tests Failing
- Check test dependencies are in `requirements.txt`
- Verify tests pass locally: `pytest -v`

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
