targetScope = 'resourceGroup'

@description('Azure region for Log Analytics and Application Insights. Defaults to the resource group location.')
param location string = resourceGroup().location

@allowed([
  'centralus'
  'eastasia'
  'eastus2'
  'westeurope'
  'westus2'
])
@description('Azure Static Web Apps deployment region.')
param staticWebAppLocation string = 'eastus2'

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

var resourceToken = uniqueString(subscription().id, resourceGroup().id, staticWebAppLocation, environmentName)
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
var staticWebAppName = 'azswa${resourceToken}'
var deploymentRoleName = 'Support Desk SWA Deployer ${environmentName}'

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

resource staticWebApp 'Microsoft.Web/staticSites@2024-11-01' = {
  name: staticWebAppName
  location: staticWebAppLocation
  tags: commonTags
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    stagingEnvironmentPolicy: 'Disabled'
    buildProperties: {
      appLocation: 'src/frontend'
      apiLocation: 'src/backend'
      outputLocation: 'dist'
      skipGithubActionWorkflowGeneration: true
    }
  }
}

resource staticWebAppSettings 'Microsoft.Web/staticSites/config@2024-11-01' = {
  parent: staticWebApp
  name: 'appsettings'
  properties: {
    APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
  }
}

resource deploymentRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(resourceGroup().id, environmentName, 'static-web-app-deployer')
  properties: {
    roleName: deploymentRoleName
    description: 'Read the generated Static Web App and retrieve its deployment token.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Web/staticSites/read'
          'Microsoft.Web/staticSites/listsecrets/action'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      resourceGroup().id
    ]
  }
}

output environmentName string = environmentName
output resourceToken string = resourceToken
output staticWebAppName string = staticWebApp.name
output applicationUrl string = 'https://${staticWebApp.properties.defaultHostname}'
output deploymentRoleName string = deploymentRole.properties.roleName
