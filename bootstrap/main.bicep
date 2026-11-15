// Bootstrap: run by a subscription admin, never by the pipeline.
// Creates the resource groups, the two GitHub identities and their roles.
targetScope = 'subscription'

@description('Region for the resource groups and identities.')
param location string

@description('Short prefix used in every name.')
@maxLength(6)
param prefix string

@description('Tags applied to every resource group and identity.')
param tags object

@description('GitHub owner name.')
param githubOwner string

@description('GitHub numeric owner ID (immutable).')
param githubOwnerId string

@description('GitHub repository name.')
param githubRepo string

@description('GitHub numeric repository ID (immutable).')
param githubRepoId string

@description('GitHub environment that gates deployments.')
param environmentName string

resource rgConnectivity 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${prefix}-connectivity'
  location: location
  tags: union(tags, { purpose: 'hub network, firewall, shared security' })
}

resource rgWorkloads 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${prefix}-workloads'
  location: location
  tags: union(tags, { purpose: 'spoke networks and test VMs' })
}

resource rgManagement 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${prefix}-management'
  location: location
  tags: union(tags, { purpose: 'logs and monitoring' })
}

// Custom role: preview deployments, nothing else.
resource whatIfRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'lz-lab-whatif-runner')
  properties: {
    roleName: 'LZ Lab What-If Runner'
    description: 'Run validate and what-if on deployments. Grants no write access.'
    type: 'customRole'
    permissions: [
      {
        actions: [
          'Microsoft.Resources/deployments/whatIf/action'
          'Microsoft.Resources/deployments/validate/action'
        ]
        notActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

module identities 'modules/identities.bicep' = {
  name: 'bootstrap-identities'
  scope: rgManagement
  params: {
    location: location
    tags: tags
    githubOwner: githubOwner
    githubOwnerId: githubOwnerId
    githubRepo: githubRepo
    githubRepoId: githubRepoId
    environmentName: environmentName
  }
}

var landingZoneGroups = [
  'rg-${prefix}-connectivity'
  'rg-${prefix}-workloads'
  'rg-${prefix}-management'
]

module access 'modules/rg-access.bicep' = [for rgName in landingZoneGroups: {
  name: 'bootstrap-access-${rgName}'
  scope: resourceGroup(rgName)
  params: {
    whatIfPrincipalId: identities.outputs.whatIfPrincipalId
    deployPrincipalId: identities.outputs.deployPrincipalId
    whatIfRoleId: whatIfRole.id
  }
  dependsOn: [
    rgConnectivity
    rgWorkloads
  ]
}]

output whatIfClientId string = identities.outputs.whatIfClientId
output deployClientId string = identities.outputs.deployClientId
