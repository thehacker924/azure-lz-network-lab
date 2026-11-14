// Phase 1 skeleton: the three landing zone resource groups.
// Later phases add modules (hub, spokes, NSGs) into these groups.
targetScope = 'subscription'

@description('Region for every resource group. The lab subscription allows eastus2.')
param location string

@description('Short prefix used in every name.')
@maxLength(6)
param prefix string

@description('Tags applied to every resource group.')
param tags object

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

output resourceGroupNames array = [
  rgConnectivity.name
  rgWorkloads.name
  rgManagement.name
]
