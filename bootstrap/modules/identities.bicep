// Two GitHub identities with one federated credential each.
@description('Region for the identities.')
param location string

@description('Tags for the identities.')
param tags object

param githubOwner string
param githubOwnerId string
param githubRepo string
param githubRepoId string
param environmentName string

var subjectBase = 'repo:${githubOwner}@${githubOwnerId}/${githubRepo}@${githubRepoId}'
var issuer = 'https://token.actions.githubusercontent.com'
var audiences = [
  'api://AzureADTokenExchange'
]

resource whatIf 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-lz-whatif'
  location: location
  tags: union(tags, { purpose: 'read-only what-if for pull requests' })
}

resource whatIfPullRequest 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: whatIf
  name: 'github-pull-request'
  properties: {
    issuer: issuer
    subject: '${subjectBase}:pull_request'
    audiences: audiences
  }
}

resource deploy 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-lz-deploy'
  location: location
  tags: union(tags, { purpose: 'deploys after approval in the GitHub environment' })
}

resource deployEnvironment 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: deploy
  name: 'github-env-${environmentName}'
  properties: {
    issuer: issuer
    subject: '${subjectBase}:environment:${environmentName}'
    audiences: audiences
  }
}

output whatIfPrincipalId string = whatIf.properties.principalId
output whatIfClientId string = whatIf.properties.clientId
output deployPrincipalId string = deploy.properties.principalId
output deployClientId string = deploy.properties.clientId
