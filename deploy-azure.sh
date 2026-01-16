#!/bin/bash
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
RESOURCE_GROUP="<your-resource-group>"        # Example: azure-function-rg
LOCATION="<your-location>"                    # Example: swedencentral, eastus, westeurope
STORAGE_ACCOUNT_NAME="<your-storage-account>"  # Example: myfuncstorageacct (3-24 chars, lowercase/numbers only)
IDENTITY_NAME="<your-identity-name>"          # Example: my-func-identity
FUNCTION_APP_NAME="<your-function-app>"        # Example: my-fastapi-func (globally unique)

# Color codes
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}============================================================================${NC}"
echo -e "${CYAN}Starting Azure Function App Deployment${NC}"
echo -e "${CYAN}============================================================================${NC}"
echo ""

# Step 1: Login to Azure
echo -e "${YELLOW}[1/10] Logging in to Azure...${NC}"
az login
if [ $? -ne 0 ]; then echo "Failed to login to Azure"; exit 1; fi
echo -e "${GREEN}✓ Successfully logged in to Azure${NC}"
echo ""

# Step 2: Add Application Insights extension
echo -e "${YELLOW}[2/10] Adding Application Insights extension...${NC}"
az extension add --name application-insights --only-show-errors
echo -e "${GREEN}✓ Application Insights extension ready${NC}"
echo ""

# Step 3: Create Resource Group (if not exists)
echo -e "${YELLOW}[3/10] Creating resource group '$RESOURCE_GROUP'...${NC}"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none
if [ $? -ne 0 ]; then echo "Failed to create resource group"; exit 1; fi
echo -e "${GREEN}✓ Resource group created/verified${NC}"
echo ""

# Step 4: Create Storage Account
echo -e "${YELLOW}[4/10] Creating storage account '$STORAGE_ACCOUNT_NAME'...${NC}"
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --location "$LOCATION" \
  --resource-group "$RESOURCE_GROUP" \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --output none
if [ $? -ne 0 ]; then echo "Failed to create storage account"; exit 1; fi
echo -e "${GREEN}✓ Storage account created${NC}"
echo ""

# Step 5: Create User-Assigned Managed Identity
echo -e "${YELLOW}[5/10] Creating user-assigned managed identity '$IDENTITY_NAME'...${NC}"
az identity create \
  --name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --output none
if [ $? -ne 0 ]; then echo "Failed to create managed identity"; exit 1; fi
echo -e "${GREEN}✓ Managed identity created${NC}"
echo ""

# Step 6: Get Identity Principal ID and Storage Account ID
echo -e "${YELLOW}[6/10] Retrieving resource IDs...${NC}"
principalId=$(az identity show \
  --name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query principalId \
  -o tsv)

storageAccountId=$(az storage account show \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id \
  -o tsv)

echo -e "${GRAY}  Principal ID: $principalId${NC}"
echo -e "${GRAY}  Storage ID: $storageAccountId${NC}"
echo -e "${GREEN}✓ Resource IDs retrieved${NC}"
echo ""

# Step 7: Assign Storage Blob Data Owner Role
echo -e "${YELLOW}[7/10] Assigning 'Storage Blob Data Owner' role to managed identity...${NC}"
az role assignment create \
  --assignee "$principalId" \
  --role "Storage Blob Data Owner" \
  --scope "$storageAccountId" \
  --output none
if [ $? -ne 0 ]; then echo "Failed to assign storage role"; exit 1; fi
echo -e "${GREEN}✓ Storage role assigned${NC}"
echo ""

# Step 8: Wait for Role Propagation
echo -e "${YELLOW}[8/10] Waiting for role assignment to propagate (30 seconds)...${NC}"
sleep 30
echo -e "${GREEN}✓ Role propagation complete${NC}"
echo ""

# Step 9: Create Function App with Flex Consumption Plan
echo -e "${YELLOW}[9/10] Creating Function App '$FUNCTION_APP_NAME' (Flex Consumption)...${NC}"
echo -e "${GRAY}  This may take a few minutes...${NC}"
az functionapp create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$FUNCTION_APP_NAME" \
  --flexconsumption-location "$LOCATION" \
  --runtime python \
  --runtime-version 3.13 \
  --storage-account "$STORAGE_ACCOUNT_NAME" \
  --deployment-storage-auth-type UserAssignedIdentity \
  --deployment-storage-auth-value "$IDENTITY_NAME" \
  --output none
if [ $? -ne 0 ]; then echo "Failed to create Function App"; exit 1; fi
echo -e "${GREEN}✓ Function App created${NC}"
echo ""

# Step 10: Configure Managed Identity for Storage and App Insights
echo -e "${YELLOW}[10/10] Configuring managed identity authentication...${NC}"

# Get client ID and App Insights ID
clientId=$(az identity show \
  --name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query clientId \
  -o tsv)

appInsightsId=$(az monitor app-insights component show \
  --app "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id \
  -o tsv)

# Set app settings for managed identity
az functionapp config appsettings set \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --settings \
    AzureWebJobsStorage__accountName="$STORAGE_ACCOUNT_NAME" \
    AzureWebJobsStorage__credential=managedidentity \
    AzureWebJobsStorage__clientId="$clientId" \
    APPLICATIONINSIGHTS_AUTHENTICATION_STRING="ClientId=$clientId;Authorization=AAD" \
  --output none

# Remove connection string setting
az functionapp config appsettings delete \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --setting-names AzureWebJobsStorage \
  --output none

# Assign Monitoring Metrics Publisher role for App Insights
az role assignment create \
  --role "Monitoring Metrics Publisher" \
  --assignee "$principalId" \
  --scope "$appInsightsId" \
  --output none

echo -e "${GREEN}✓ Managed identity authentication configured${NC}"
echo ""

# Deployment Complete
echo -e "${CYAN}============================================================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${CYAN}============================================================================${NC}"
echo ""
echo -e "${WHITE}Function App URL: https://$FUNCTION_APP_NAME.azurewebsites.net${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "${WHITE}  1. Deploy your code: func azure functionapp publish $FUNCTION_APP_NAME${NC}"
echo -e "${WHITE}  2. Test your API at: https://$FUNCTION_APP_NAME.azurewebsites.net/api/${NC}"
echo ""
echo -e "${YELLOW}Key Features Configured:${NC}"
echo -e "${WHITE}  ✓ Flex Consumption Plan (serverless, pay-per-execution)${NC}"
echo -e "${WHITE}  ✓ User-Assigned Managed Identity (keyless authentication)${NC}"
echo -e "${WHITE}  ✓ Storage with managed identity (no connection strings)${NC}"
echo -e "${WHITE}  ✓ Application Insights with AAD authentication${NC}"
echo ""
