targetScope = 'resourceGroup'

@description('Azure region for the App Service and monitoring resources.')
param location string = resourceGroup().location

@minLength(4)
@maxLength(32)
@description('Environment name generated from the deployer initials and the 01 suffix.')
param environmentName string

@maxLength(32)
@description('Optional human-readable label used only for tags.')
param deploymentLabel string = 'aisdlc'

@description('Unique session identifier from the prepare-plan.')
param sessionId string = environmentName

@description('Name or email of the deployer.')
param deployedBy string = 'azure-cli'

@description('ISO 8601 timestamp when the deployment was created.')
param createdAt string = utcNow()

var resourceToken = uniqueString(subscription().id, resourceGroup().id, environmentName)
var commonTags = {
  'app-onboard-skill': 'true'
  'app-onboard-session-id': sessionId
  'created-at': createdAt
  'deployed-by': deployedBy
  application: 'support-desk-simulator'
  environment: 'workshop'
  'deployment-label': deploymentLabel
  'environment-name': environmentName
  'managed-by': 'bicep'
}

var logAnalyticsName = 'azlaw${resourceToken}'
var applicationInsightsName = 'azai${resourceToken}'
var appServicePlanName = 'asp-${resourceToken}'
var webAppName = 'app-${resourceToken}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2026-03-01' = {
  name: logAnalyticsName
  location: location
  tags: commonTags
  properties: {
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  tags: commonTags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appServicePlan 'Microsoft.Web/serverFarms@2026-08-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  tags: commonTags
  sku: {
    name: 'B1'
    tier: 'Basic'
    capacity: 1
  }
  properties: {
    reserved: true
    zoneRedundant: false
  }
}

resource webApp 'Microsoft.Web/sites@2026-08-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  tags: commonTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|10.0'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      webSocketsEnabled: true
      healthCheckPath: '/api/health'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
      ]
    }
  }
}

output environmentName string = environmentName
output appServicePlanName string = appServicePlan.name
output webAppName string = webApp.name
output applicationUrl string = 'https://${webApp.properties.defaultHostName}'
