// One side of a VNet peering. Deploy it in the resource group of the local VNet.
@description('Name of the local virtual network (in this resource group).')
param localVnetName string

@description('Name of the peering.')
param peeringName string

@description('Resource ID of the remote virtual network.')
param remoteVnetId string

resource localVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: localVnetName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: localVnet
  name: peeringName
  properties: {
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
    allowVirtualNetworkAccess: true
    // Needed in Phase 7 so traffic forwarded by the hub firewall is accepted.
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}
