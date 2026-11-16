// Landing zone network. Deployed into rg-lz-connectivity by the pipeline.
// Hub lives here; spokes, NSGs and ASGs live in the workloads resource group.
targetScope = 'resourceGroup'

@description('Region for every resource. Defaults to this resource group region.')
param location string = resourceGroup().location

@description('Resource group that holds the spoke networks, NSGs and ASGs.')
param workloadsResourceGroup string

@description('Tags applied to every resource.')
param tags object

@description('Hub network: name, addressPrefix, subnets.')
param hub object

@description('Spoke networks: each has name, addressPrefix, subnets.')
param spokes array

@description('Application security groups to create in the workloads resource group.')
param asgNames array

// Rules as data: one file per NSG in network-policy/.
var nsgPolicies = [
  loadJsonContent('../network-policy/nsg-lz-spoke1-web.json')
  loadJsonContent('../network-policy/nsg-lz-spoke1-app.json')
  loadJsonContent('../network-policy/nsg-lz-spoke2-data.json')
]

var hubVnetId = resourceId('Microsoft.Network/virtualNetworks', hub.name)

module asgs 'modules/asgs.bicep' = {
  name: 'sec-asgs'
  scope: resourceGroup(workloadsResourceGroup)
  params: {
    names: asgNames
    location: location
    tags: tags
  }
}

module nsgs 'modules/nsg.bicep' = [for policy in nsgPolicies: {
  name: 'sec-${policy.nsgName}'
  scope: resourceGroup(workloadsResourceGroup)
  params: {
    policy: policy
    location: location
    tags: tags
  }
  dependsOn: [
    asgs
  ]
}]

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
  dependsOn: [
    nsgs
  ]
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
