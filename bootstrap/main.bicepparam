using './main.bicep'

param location = 'eastus2'
param prefix = 'lz'
param tags = {
  project: 'azure-lz-network-lab'
  environment: 'lab'
  managedBy: 'bicep'
  costCenter: 'lab-demo'
}
param githubOwner = 'thehacker924'
param githubOwnerId = '198147991'
param githubRepo = 'azure-lz-network-lab'
param githubRepoId = '1457554376'
param environmentName = 'lz-lab'
