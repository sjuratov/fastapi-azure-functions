# ============================================================================
# Azure Function App Deployment Script with Managed Identity
# ============================================================================
# This script deploys a FastAPI-based Azure Function App using:
# - Flex Consumption Plan (supports managed identity during creation)
# - User-Assigned Managed Identity (for secure, keyless authentication)
# - Storage Account with shared key access disabled
# - Application Insights with managed identity authentication
# ============================================================================

# Configuration Variables - Update these for your deployment
$ResourceGroup = "<your-resource-group>"        # Example: azure-function-rg
$Location = "<your-location>"                    # Example: swedencentral, eastus, westeurope
$StorageAccountName = "<your-storage-account>"  # Example: myfuncstorageacct (3-24 chars, lowercase/numbers only)
$IdentityName = "<your-identity-name>"          # Example: my-func-identity
$FunctionAppName = "<your-function-app>"        # Example: my-fastapi-func (globally unique)

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "Starting Azure Function App Deployment" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Login to Azure
Write-Host "[1/10] Logging in to Azure..." -ForegroundColor Yellow
az login
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to login to Azure"; exit 1 }
Write-Host "✓ Successfully logged in to Azure" -ForegroundColor Green
Write-Host ""

# Step 2: Add Application Insights extension
Write-Host "[2/10] Adding Application Insights extension..." -ForegroundColor Yellow
az extension add --name application-insights --only-show-errors
Write-Host "✓ Application Insights extension ready" -ForegroundColor Green
Write-Host ""

# Step 3: Create Resource Group (if not exists)
Write-Host "[3/10] Creating resource group '$ResourceGroup'..." -ForegroundColor Yellow
az group create `
  --name $ResourceGroup `
  --location $Location `
  --output none
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create resource group"; exit 1 }
Write-Host "✓ Resource group created/verified" -ForegroundColor Green
Write-Host ""

# Step 4: Create Storage Account
Write-Host "[4/10] Creating storage account '$StorageAccountName'..." -ForegroundColor Yellow
az storage account create `
  --name $StorageAccountName `
  --location $Location `
  --resource-group $ResourceGroup `
  --sku Standard_LRS `
  --allow-blob-public-access false `
  --output none
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create storage account"; exit 1 }
Write-Host "✓ Storage account created" -ForegroundColor Green
Write-Host ""

# Step 5: Create User-Assigned Managed Identity
Write-Host "[5/10] Creating user-assigned managed identity '$IdentityName'..." -ForegroundColor Yellow
az identity create `
  --name $IdentityName `
  --resource-group $ResourceGroup `
  --output none
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create managed identity"; exit 1 }
Write-Host "✓ Managed identity created" -ForegroundColor Green
Write-Host ""

# Step 6: Get Identity Principal ID and Storage Account ID
Write-Host "[6/10] Retrieving resource IDs..." -ForegroundColor Yellow
$principalId = az identity show `
  --name $IdentityName `
  --resource-group $ResourceGroup `
  --query principalId `
  -o tsv

$storageAccountId = az storage account show `
  --name $StorageAccountName `
  --resource-group $ResourceGroup `
  --query id `
  -o tsv

Write-Host "  Principal ID: $principalId" -ForegroundColor Gray
Write-Host "  Storage ID: $storageAccountId" -ForegroundColor Gray
Write-Host "✓ Resource IDs retrieved" -ForegroundColor Green
Write-Host ""

# Step 7: Assign Storage Blob Data Owner Role
Write-Host "[7/10] Assigning 'Storage Blob Data Owner' role to managed identity..." -ForegroundColor Yellow
az role assignment create `
  --assignee $principalId `
  --role "Storage Blob Data Owner" `
  --scope $storageAccountId `
  --output none
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to assign storage role"; exit 1 }
Write-Host "✓ Storage role assigned" -ForegroundColor Green
Write-Host ""

# Step 8: Wait for Role Propagation
Write-Host "[8/10] Waiting for role assignment to propagate (30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
Write-Host "✓ Role propagation complete" -ForegroundColor Green
Write-Host ""

# Step 9: Create Function App with Flex Consumption Plan
Write-Host "[9/10] Creating Function App '$FunctionAppName' (Flex Consumption)..." -ForegroundColor Yellow
Write-Host "  This may take a few minutes..." -ForegroundColor Gray
az functionapp create `
  --resource-group $ResourceGroup `
  --name $FunctionAppName `
  --flexconsumption-location $Location `
  --runtime python `
  --runtime-version 3.13 `
  --storage-account $StorageAccountName `
  --deployment-storage-auth-type UserAssignedIdentity `
  --deployment-storage-auth-value $IdentityName `
  --output none
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create Function App"; exit 1 }
Write-Host "✓ Function App created" -ForegroundColor Green
Write-Host ""

# Step 10: Configure Managed Identity for Storage and App Insights
Write-Host "[10/10] Configuring managed identity authentication..." -ForegroundColor Yellow

# Get client ID and App Insights ID
$clientId = az identity show `
  --name $IdentityName `
  --resource-group $ResourceGroup `
  --query clientId `
  -o tsv

$appInsightsId = az monitor app-insights component show `
  --app $FunctionAppName `
  --resource-group $ResourceGroup `
  --query id `
  -o tsv

# Set app settings for managed identity
az functionapp config appsettings set `
  --name $FunctionAppName `
  --resource-group $ResourceGroup `
  --settings `
    AzureWebJobsStorage__accountName=$StorageAccountName `
    AzureWebJobsStorage__credential=managedidentity `
    "AzureWebJobsStorage__clientId=$clientId" `
    "APPLICATIONINSIGHTS_AUTHENTICATION_STRING=ClientId=$clientId;Authorization=AAD" `
  --output none

# Remove connection string setting
az functionapp config appsettings delete `
  --name $FunctionAppName `
  --resource-group $ResourceGroup `
  --setting-names AzureWebJobsStorage `
  --output none

# Assign Monitoring Metrics Publisher role for App Insights
az role assignment create `
  --role "Monitoring Metrics Publisher" `
  --assignee $principalId `
  --scope $appInsightsId `
  --output none

Write-Host "✓ Managed identity authentication configured" -ForegroundColor Green
Write-Host ""

# Deployment Complete
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Function App URL: https://$FunctionAppName.azurewebsites.net" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Deploy your code: func azure functionapp publish $FunctionAppName" -ForegroundColor White
Write-Host "  2. Test your API at: https://$FunctionAppName.azurewebsites.net/api/" -ForegroundColor White
Write-Host ""
Write-Host "Key Features Configured:" -ForegroundColor Yellow
Write-Host "  ✓ Flex Consumption Plan (serverless, pay-per-execution)" -ForegroundColor White
Write-Host "  ✓ User-Assigned Managed Identity (keyless authentication)" -ForegroundColor White
Write-Host "  ✓ Storage with managed identity (no connection strings)" -ForegroundColor White
Write-Host "  ✓ Application Insights with AAD authentication" -ForegroundColor White
Write-Host ""
