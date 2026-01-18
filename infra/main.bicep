targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@description('Seed string used to generate all resource names. Defaults to environmentName when empty.')
param nameSeed string = ''

@minLength(1)
@description('Primary location for all resources & Flex Consumption Function App')
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

param functionAppName string = ''
param userAssignedIdentityName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''
param storageAccountName string = ''

@description('Allow the deploying user identity to access storage for deployment packages.')
param allowUserIdentityPrincipal bool = true

@description('Id of the user identity to be used for testing and debugging. Leave empty if not needed.')
param principalId string = deployer().objectId

var abbrs = loadJsonContent('./abbreviations.json')
var effectiveSeed = !empty(nameSeed) ? nameSeed : environmentName
var normalizedSeed = toLower(replace(effectiveSeed, ' ', ''))
var resourceToken = toLower(uniqueString(subscription().id, normalizedSeed, location))
var tags = { 'azd-env-name': environmentName }

var resolvedResourceGroupName = !empty(resourceGroupName)
  ? resourceGroupName
  : '${abbrs.resourcesResourceGroups}${normalizedSeed}'

var resolvedFunctionAppName = !empty(functionAppName)
  ? functionAppName
  : '${abbrs.webSitesFunctions}${normalizedSeed}-${resourceToken}'

var resolvedIdentityName = !empty(userAssignedIdentityName)
  ? userAssignedIdentityName
  : '${abbrs.managedIdentityUserAssignedIdentities}${normalizedSeed}-${resourceToken}'

var resolvedStorageAccountName = !empty(storageAccountName)
  ? storageAccountName
  : '${abbrs.storageStorageAccounts}${normalizedSeed}${take(resourceToken, 6)}'

var resolvedLogAnalyticsName = !empty(logAnalyticsName)
  ? logAnalyticsName
  : '${abbrs.operationalInsightsWorkspaces}${normalizedSeed}-${resourceToken}'

var resolvedAppInsightsName = !empty(applicationInsightsName)
  ? applicationInsightsName
  : '${abbrs.insightsComponents}${normalizedSeed}-${resourceToken}'

var resolvedPlanName = !empty(appServicePlanName)
  ? appServicePlanName
  : '${abbrs.webServerFarms}${normalizedSeed}-${resourceToken}'

var deploymentStorageContainerName = 'app-package-${take(resolvedFunctionAppName, 32)}-${take(resourceToken, 7)}'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resolvedResourceGroupName
  location: location
  tags: tags
}

module apiUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: 'apiUserAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    name: resolvedIdentityName
  }
}

module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: resolvedPlanName
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
    }
    reserved: true
    location: location
    tags: tags
  }
}

module storage 'br/public:avm/res/storage/storage-account:0.8.3' = {
  name: 'storage'
  scope: rg
  params: {
    name: resolvedStorageAccountName
    allowBlobPublicAccess: false
    skuName: 'Standard_LRS'
    location: location
    tags: tags
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    blobServices: {
      containers: [{ name: deploymentStorageContainerName }]
    }
  }
}

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: '${uniqueString(deployment().name, location)}-loganalytics'
  scope: rg
  params: {
    name: resolvedLogAnalyticsName
    location: location
    tags: tags
    dataRetention: 30
  }
}

module monitoring 'br/public:avm/res/insights/component:0.6.0' = {
  name: '${uniqueString(deployment().name, location)}-appinsights'
  scope: rg
  params: {
    name: resolvedAppInsightsName
    location: location
    tags: tags
    workspaceResourceId: logAnalytics.outputs.resourceId
    disableLocalAuth: true
  }
}

var storageEndpointConfig = {
  enableBlob: true
  enableQueue: false
  enableTable: false
  enableFiles: false
  allowUserIdentityPrincipal: allowUserIdentityPrincipal
}

module api './app/api.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: resolvedFunctionAppName
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.name
    appServicePlanId: appServicePlan.outputs.resourceId
    runtimeName: 'python'
    runtimeVersion: '3.13'
    storageAccountName: storage.outputs.name
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
    deploymentStorageContainerName: deploymentStorageContainerName
    identityId: apiUserAssignedIdentity.outputs.resourceId
    identityClientId: apiUserAssignedIdentity.outputs.clientId
    appSettings: {}
  }
}

module rbac './app/rbac.bicep' = {
  name: 'rbacAssignments'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    appInsightsName: monitoring.outputs.name
    managedIdentityPrincipalId: apiUserAssignedIdentity.outputs.principalId
    userIdentityPrincipalId: principalId
    enableBlob: storageEndpointConfig.enableBlob
    enableQueue: storageEndpointConfig.enableQueue
    enableTable: storageEndpointConfig.enableTable
    allowUserIdentityPrincipal: storageEndpointConfig.allowUserIdentityPrincipal
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output RESOURCE_GROUP string = rg.name
output AZURE_FUNCTION_APP_NAME string = api.outputs.SERVICE_API_NAME
output AZURE_STORAGE_ACCOUNT_NAME string = storage.outputs.name
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.connectionString
