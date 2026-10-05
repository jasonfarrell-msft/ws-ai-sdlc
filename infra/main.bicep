targetScope = 'resourceGroup'

@description('Azure region for the Container Apps environment and monitoring resources.')
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

@description('API image to retain during infrastructure updates; replaced by deploy.ps1 after the first build.')
param backendImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Frontend image to retain during infrastructure updates; replaced by deploy.ps1 after the first build.')
param frontendImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

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
var registryName = 'acr${resourceToken}'
var managedEnvironmentName = 'cae${resourceToken}'
var backendAppName = 'ca-api-${environmentName}'
var frontendAppName = 'ca-web-${environmentName}'
var deploymentRoleName = 'Support Desk Container App Deployer ${environmentName}'

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

resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: registryName
  location: location
  tags: commonTags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2026-07-01' = {
  name: managedEnvironmentName
  location: location
  tags: commonTags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource backendApp 'Microsoft.App/containerApps@2026-07-01' = {
  name: backendAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: commonTags
  properties: {
    managedEnvironmentId: managedEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
        allowInsecure: false
      }
      registries: [
        {
          server: registry.properties.loginServer
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: backendImage
          env: [
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: applicationInsights.properties.ConnectionString
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

resource frontendApp 'Microsoft.App/containerApps@2026-07-01' = {
  name: frontendAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: commonTags
  properties: {
    managedEnvironmentId: managedEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
        allowInsecure: false
      }
      registries: [
        {
          server: registry.properties.loginServer
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'web'
          image: frontendImage
          env: [
            {
              name: 'BACKEND_URL'
              value: 'https://${backendApp.properties.configuration.ingress.fqdn}'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
      }
    }
  }
}

resource backendPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, backendApp.id, 'acrpull')
  scope: registry
  properties: {
    principalId: backendApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
  }
}

resource frontendPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, frontendApp.id, 'acrpull')
  scope: registry
  properties: {
    principalId: frontendApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
  }
}

resource deploymentRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(resourceGroup().id, environmentName, 'container-app-deployer')
  properties: {
    roleName: deploymentRoleName
    description: 'Build images in the generated registry and update the generated Container Apps.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.ContainerRegistry/registries/read'
          'Microsoft.ContainerRegistry/registries/listBuildSourceUploadUrl/action'
          'Microsoft.ContainerRegistry/registries/scheduleRun/action'
          'Microsoft.ContainerRegistry/registries/runs/read'
          'Microsoft.ContainerRegistry/registries/runs/listLogSasUrl/action'
          'Microsoft.App/containerApps/read'
          'Microsoft.App/containerApps/write'
          'Microsoft.App/managedEnvironments/read'
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
output containerRegistryName string = registry.name
output containerRegistryLoginServer string = registry.properties.loginServer
output containerEnvironmentName string = managedEnvironment.name
output backendAppName string = backendApp.name
output frontendAppName string = frontendApp.name
output backendUrl string = 'https://${backendApp.properties.configuration.ingress.fqdn}'
output applicationUrl string = 'https://${frontendApp.properties.configuration.ingress.fqdn}'
output deploymentRoleName string = deploymentRole.properties.roleName
