targetScope = 'resourceGroup'

@description('Azure region for all regional resources. Defaults to the resource group location.')
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

@description('Enables diagnostic settings after the application resources are ready.')
param enableDiagnostics bool = true

@description('Current GA Node.js runtime used by the frontend Linux App Service.')
param nodeRuntime string = 'NODE|24-lts'

@description('Current GA Python runtime used by the backend Linux App Service.')
param pythonRuntime string = 'PYTHON|3.13'

var resourceToken = uniqueString(subscription().id, resourceGroup().id, location, environmentName)
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
var appServicePlanName = 'azasp${resourceToken}'
var frontendAppName = 'azwebfe${resourceToken}'
var backendAppName = 'azwebbe${resourceToken}'
var frontendOrigin = 'https://${frontendApp.properties.defaultHostName}'
var backendOrigin = 'https://${backendApp.properties.defaultHostName}'

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

resource appServicePlan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  tags: commonTags
  sku: {
    name: 'S1'
    tier: 'Standard'
    size: 'S1'
    capacity: 1
  }
  properties: {
    reserved: true
    zoneRedundant: false
  }
}

resource frontendApp 'Microsoft.Web/sites@2025-03-01' = {
  name: frontendAppName
  location: location
  kind: 'app,linux'
  tags: commonTags
  properties: {
    clientAffinityEnabled: false
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    serverFarmId: appServicePlan.id
    siteConfig: {
      alwaysOn: true
      appCommandLine: 'pm2 serve /home/site/wwwroot --no-daemon --spa'
      ftpsState: 'Disabled'
      http20Enabled: true
      linuxFxVersion: nodeRuntime
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITE_HTTPLOGGING_RETENTION_DAYS'
          value: '7'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~24'
        }
      ]
    }
  }
}

resource backendApp 'Microsoft.Web/sites@2025-03-01' = {
  name: backendAppName
  location: location
  kind: 'app,linux'
  tags: commonTags
  properties: {
    clientAffinityEnabled: false
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    serverFarmId: appServicePlan.id
    siteConfig: {
      alwaysOn: true
      appCommandLine: 'python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --no-access-log'
      ftpsState: 'Disabled'
      healthCheckPath: '/api/health'
      http20Enabled: true
      linuxFxVersion: pythonRuntime
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'FRONTEND_ORIGIN'
          value: frontendOrigin
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'true'
        }
        {
          name: 'WEBSITE_HTTPLOGGING_RETENTION_DAYS'
          value: '7'
        }
      ]
    }
  }
}

resource frontendPublishingCredentialsPoliciesFtp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  parent: frontendApp
  name: 'ftp'
  properties: {
    allow: false
  }
}

resource frontendPublishingCredentialsPoliciesScm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  parent: frontendApp
  name: 'scm'
  properties: {
    allow: false
  }
}

resource backendPublishingCredentialsPoliciesFtp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  parent: backendApp
  name: 'ftp'
  properties: {
    allow: false
  }
}

resource backendPublishingCredentialsPoliciesScm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  parent: backendApp
  name: 'scm'
  properties: {
    allow: false
  }
}

resource frontendDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: 'azdsfe${resourceToken}'
  scope: frontendApp
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource backendDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: 'azdsbe${resourceToken}'
  scope: backendApp
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output environmentName string = environmentName
output resourceToken string = resourceToken
output frontendAppName string = frontendApp.name
output frontendUrl string = frontendOrigin
output backendAppName string = backendApp.name
output backendUrl string = backendOrigin
