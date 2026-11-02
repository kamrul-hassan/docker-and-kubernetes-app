// Azure infrastructure for TaskFlow:
//   Log Analytics · Azure Container Registry · AKS (app routing add-on) ·
//   Azure Database for PostgreSQL Flexible Server
//
// Deploy:  az deployment group create -g <rg> -f infra/main.bicep -p infra/main.bicepparam

@description('Short prefix used in resource names (lowercase letters/numbers, 3-11 chars).')
@minLength(3)
@maxLength(11)
param prefix string = 'taskflow'

param location string = resourceGroup().location

@description('AKS node VM size.')
param aksNodeVmSize string = 'Standard_D2as_v5'

@minValue(1)
param aksNodeCount int = 2

@description('Region for PostgreSQL (can differ from AKS when a SKU is restricted in one region).')
param postgresLocation string = location

param postgresAdminUser string = 'taskflowadmin'

@secure()
@description('PostgreSQL administrator password.')
param postgresAdminPassword string

param postgresDatabaseName string = 'taskflow'

var suffix = uniqueString(resourceGroup().id)
var acrName = toLower('${prefix}acr${suffix}')
var aksName = '${prefix}-aks'
var pgName = '${prefix}-pg-${uniqueString(resourceGroup().id, postgresLocation)}'

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${prefix}-logs'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: { name: 'Basic' }
  properties: {
    adminUserEnabled: false
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2024-09-01' = {
  name: aksName
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    dnsPrefix: '${prefix}-${suffix}'
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        vmSize: aksNodeVmSize
        count: aksNodeCount
        osType: 'Linux'
        osSKU: 'AzureLinux'
        type: 'VirtualMachineScaleSets'
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
    }
    // Managed NGINX ingress controller (ingressClassName: webapprouting.kubernetes.azure.com)
    ingressProfile: {
      webAppRouting: { enabled: true }
    }
    oidcIssuerProfile: { enabled: true }
    securityProfile: {
      workloadIdentity: { enabled: true }
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: { logAnalyticsWorkspaceResourceID: logs.id }
      }
    }
  }
}

// Let the cluster's kubelet identity pull images from ACR
var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource aksAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, aks.id, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: acrPullRoleId
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

resource pg 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: pgName
  location: postgresLocation
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '16'
    administratorLogin: postgresAdminUser
    administratorLoginPassword: postgresAdminPassword
    storage: { storageSizeGB: 32 }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: { mode: 'Disabled' }
    network: { publicNetworkAccess: 'Enabled' }
  }
}

// Allows connections from Azure services (including AKS egress).
// For production, switch to VNet integration / private endpoint.
resource pgAllowAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = {
  parent: pg
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource pgDb 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  parent: pg
  name: postgresDatabaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output aksName string = aks.name
output postgresHost string = pg.properties.fullyQualifiedDomainName
output postgresDatabase string = pgDb.name
