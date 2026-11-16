// Landing zone network. Deployed into rg-lz-connectivity by the pipeline.
// Hub lives here; spokes live in the workloads resource group.
targetScope = 'resourceGroup'

@description('Region for every resource. Defaults to this resource group region.')
param location string = resourceGroup().location

@description('Resource group that holds the spoke networks.')
param workloadsResourceGroup string

@description('Tags applied to every resource.')
param tags object

@description('Hub network: name, addressPrefix, subnets.')
param hub object

@description('Spoke networks: each has name, addressPrefix, subnets.')
param spokes array

var hubVnetId = resourceId('Microsoft.Network/virtualNetworks', hub.name)

module hubVnet 'modules/vnet.bicep' = {
  name: 'net-${hub.name}'
  params: {
    name: hub.name
    location: location
    tags: union(tags, { role: 'hub' })
    addressPrefix: hub.addressPrefix
    subnets: hub.subnets
  }
}

module spokeVnets 'modules/vnet.bicep' = [for spoke in spokes: {
  name: 'net-${spoke.name}'
  scope: resourceGroup(workloadsResourceGroup)
  params: {
    name: spoke.name
    location: location
    tags: union(tags, { role: 'spoke' })
    addressPrefix: spoke.addressPrefix
    subnets: spoke.subnets
  }
}]

// Hub side: one at a time, because both write to the same hub VNet.
@batchSize(1)
module hubToSpoke 'modules/peering.bicep' = [for spoke in spokes: {
  name: 'peer-hub-to-${spoke.name}'
  params: {
    localVnetName: hub.name
    peeringName: 'peer-${hub.name}-to-${spoke.name}'
    remoteVnetId: resourceId(workloadsResourceGroup, 'Microsoft.Network/virtualNetworks', spoke.name)
  }
  dependsOn: [
    hubVnet
    spokeVnets
  ]
}]

module spokeToHub 'modules/peering.bicep' = [for spoke in spokes: {
  name: 'peer-${spoke.name}-to-hub'
  scope: resourceGroup(workloadsResourceGroup)
  params: {
    localVnetName: spoke.name
    peeringName: 'peer-${spoke.name}-to-${hub.name}'
    remoteVnetId: hubVnetId
  }
  dependsOn: [
    hubVnet
    spokeVnets
  ]
}]

output hubVnetId string = hubVnetId
