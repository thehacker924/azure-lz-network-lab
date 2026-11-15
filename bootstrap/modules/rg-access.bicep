// Role assignments for one landing zone resource group.
@description('Principal ID of the what-if identity.')
param whatIfPrincipalId string

@description('Principal ID of the deploy identity.')
param deployPrincipalId string

@description('Resource ID of the custom what-if role.')
param whatIfRoleId string

var readerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

resource whatIfReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, whatIfPrincipalId, readerRoleId)
  properties: {
    roleDefinitionId: readerRoleId
    principalId: whatIfPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource whatIfRunner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, whatIfPrincipalId, whatIfRoleId)
  properties: {
    roleDefinitionId: whatIfRoleId
    principalId: whatIfPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource deployContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deployPrincipalId, contributorRoleId)
  properties: {
    roleDefinitionId: contributorRoleId
    principalId: deployPrincipalId
    principalType: 'ServicePrincipal'
  }
}
